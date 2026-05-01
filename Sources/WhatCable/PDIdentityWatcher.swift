import Foundation
import IOKit

/// Watches `IOPortTransportComponentCCUSBPDSOP` services. These hold the PD
/// Discover Identity response for the port partner (SOP) and any e-marker
/// chips on the cable (SOP', SOP'').
@MainActor
final class PDIdentityWatcher: ObservableObject {
    @Published private(set) var identities: [PDIdentity] = []

    private var notifyPort: IONotificationPortRef?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0

    func start() {
        guard notifyPort == nil else { return }
        let port = IONotificationPortCreate(kIOMainPortDefault)
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        notifyPort = port

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let added: IOServiceMatchingCallback = { refcon, iter in
            guard let refcon else { return }
            let w = Unmanaged<PDIdentityWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in w.handleAdded(iter) }
        }
        let removed: IOServiceMatchingCallback = { refcon, iter in
            guard let refcon else { return }
            let w = Unmanaged<PDIdentityWatcher>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in w.handleRemoved(iter) }
        }

        IOServiceAddMatchingNotification(port, kIOMatchedNotification,
            IOServiceMatching("IOPortTransportComponentCCUSBPDSOP"),
            added, selfPtr, &addedIter)
        handleAdded(addedIter)

        IOServiceAddMatchingNotification(port, kIOTerminatedNotification,
            IOServiceMatching("IOPortTransportComponentCCUSBPDSOP"),
            removed, selfPtr, &removedIter)
        handleRemoved(removedIter)
    }

    func stop() {
        if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
        if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }
        if let p = notifyPort { IONotificationPortDestroy(p); notifyPort = nil }
        identities.removeAll()
    }

    func refresh() {
        identities.removeAll()
        var iter: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault,
            IOServiceMatching("IOPortTransportComponentCCUSBPDSOP"), &iter) == KERN_SUCCESS {
            handleAdded(iter)
            IOObjectRelease(iter)
        }
    }

    private func handleAdded(_ iter: io_iterator_t) {
        while case let service = IOIteratorNext(iter), service != 0 {
            if let identity = makeIdentity(from: service),
               !identities.contains(where: { $0.id == identity.id }) {
                identities.append(identity)
            }
            IOObjectRelease(service)
        }
    }

    private func handleRemoved(_ iter: io_iterator_t) {
        while case let service = IOIteratorNext(iter), service != 0 {
            let entryID = IOKitSupport.entryID(for: service)
            identities.removeAll { $0.id == entryID }
            IOObjectRelease(service)
        }
    }

    private func makeIdentity(from service: io_service_t) -> PDIdentity? {
        let entryID = IOKitSupport.entryID(for: service)
        guard let dict = IOKitSupport.properties(for: service) else { return nil }

        let endpointName = (dict["ComponentName"] as? String)
            ?? (dict["AddressDescription"] as? String)
            ?? (dict["Address Description"] as? String)
            ?? "Unknown"
        let endpoint = PDIdentity.Endpoint(rawValue: endpointName) ?? .unknown

        let parentType = (dict["ParentPortType"] as? NSNumber)?.intValue ?? 0
        let parentNum = (dict["ParentPortNumber"] as? NSNumber)?.intValue ?? 0
        let specRev = (dict["Specification Revision"] as? NSNumber)?.intValue ?? 0

        let metadata = dict["Metadata"] as? [String: Any] ?? [:]
        let vendorID = (metadata["Vendor ID"] as? NSNumber)?.intValue
            ?? (dict["Vendor ID"] as? NSNumber)?.intValue ?? 0
        let productID = (metadata["Product ID"] as? NSNumber)?.intValue
            ?? (dict["Product ID"] as? NSNumber)?.intValue ?? 0
        let bcdDevice = (metadata["bcdDevice"] as? NSNumber)?.intValue ?? 0

        let vdos: [UInt32] = ((metadata["VDOs"] as? [Any]) ?? []).compactMap { value in
            guard let data = value as? Data else { return nil }
            return PDVDO.vdoFromData(data)
        }

        return PDIdentity(
            id: entryID,
            endpoint: endpoint,
            parentPortType: parentType,
            parentPortNumber: parentNum,
            vendorID: vendorID,
            productID: productID,
            bcdDevice: bcdDevice,
            vdos: vdos,
            specRevision: specRev
        )
    }

}
