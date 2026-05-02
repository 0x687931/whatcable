import Combine
import Foundation

@MainActor
final class CableStateStore: ObservableObject {
    static let shared = CableStateStore()
    private static let livePortRefreshInterval: TimeInterval = 3
    private static let livePortRefreshTolerance: TimeInterval = 1

    @Published private(set) var ports: [USBCPort] = []
    @Published private(set) var devices: [USBDevice] = []
    @Published private(set) var sources: [PowerSource] = []
    @Published private(set) var identities: [PDIdentity] = []
    @Published private(set) var sessionQualityDiagnostics: [UInt64: SessionQualityDiagnostic] = [:]

    private let portWatcher = USBCPortWatcher()
    private let deviceWatcher = USBWatcher()
    private let powerWatcher = PowerSourceWatcher()
    private let pdWatcher = PDIdentityWatcher()
    private var cancellables = Set<AnyCancellable>()
    private var liveRefreshCancellable: AnyCancellable?
    private var sessionSnapshots: [UInt64: SessionQualitySnapshot] = [:]
    private var isRefreshingPorts = false
    private var isRunning = false

    private init() {
        portWatcher.$ports
            .sink { [weak self] in self?.handlePorts($0) }
            .store(in: &cancellables)
        deviceWatcher.$devices
            .sink { [weak self] in self?.devices = $0 }
            .store(in: &cancellables)
        powerWatcher.$sources
            .sink { [weak self] in self?.sources = $0 }
            .store(in: &cancellables)
        pdWatcher.$identities
            .sink { [weak self] in self?.identities = $0 }
            .store(in: &cancellables)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        portWatcher.start()
        deviceWatcher.start()
        powerWatcher.start()
        pdWatcher.start()
        startLivePortRefresh()
    }

    func refresh() {
        start()
        refreshPortState()
        deviceWatcher.refresh()
        powerWatcher.refresh()
        pdWatcher.refresh()
    }

    func sessionQualityDiagnostic(for port: USBCPort) -> SessionQualityDiagnostic? {
        sessionQualityDiagnostics[port.id]
    }

    func sources(for port: USBCPort) -> [PowerSource] {
        guard let key = port.portKey else { return [] }
        return sources.filter { $0.portKey == key }
    }

    func identities(for port: USBCPort) -> [PDIdentity] {
        guard let key = port.portKey else { return [] }
        return identities.filter { $0.portKey == key }
    }

    func devices(for port: USBCPort) -> [USBDevice] {
        port.matchingDevices(from: devices)
    }

    private func startLivePortRefresh() {
        guard liveRefreshCancellable == nil else { return }
        liveRefreshCancellable = Timer.publish(
            every: Self.livePortRefreshInterval,
            tolerance: Self.livePortRefreshTolerance,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.refreshPortState()
        }
    }

    private func refreshPortState() {
        isRefreshingPorts = true
        portWatcher.refresh()
        isRefreshingPorts = false

        if portWatcher.ports.isEmpty, !ports.isEmpty {
            handlePorts([])
        }
    }

    private func handlePorts(_ currentPorts: [USBCPort]) {
        if isRefreshingPorts, currentPorts.isEmpty, !ports.isEmpty {
            return
        }

        var nextDiagnostics: [UInt64: SessionQualityDiagnostic] = [:]

        for port in currentPorts {
            guard port.connectionActive == true else {
                sessionSnapshots.removeValue(forKey: port.id)
                continue
            }

            let snapshot = sessionSnapshots[port.id] ?? SessionQualitySnapshot(port: port)
            sessionSnapshots[port.id] = snapshot
            if let diagnostic = snapshot.diagnostic(for: port) {
                nextDiagnostics[port.id] = diagnostic
            }
        }

        if ports != currentPorts {
            ports = currentPorts
        }
        if sessionQualityDiagnostics != nextDiagnostics {
            sessionQualityDiagnostics = nextDiagnostics
        }
    }
}
