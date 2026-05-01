import Foundation
import IOKit

enum IOKitSupport {
    static func entryID(for service: io_service_t) -> UInt64 {
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        return entryID
    }

    static func properties(for service: io_service_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dict
    }

    static func stringProperties(from dict: [String: Any]) -> [String: String] {
        var raw: [String: String] = [:]
        for (key, value) in dict {
            raw[key] = stringify(value)
        }
        return raw
    }

    static func hexData(_ value: Any?) -> String? {
        guard let data = value as? Data else { return nil }
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func stringify(_ value: Any) -> String {
        switch value {
        case let n as NSNumber:
            return n.stringValue
        case let s as String:
            return s
        case let d as Data:
            return d.map { String(format: "%02X", $0) }.joined(separator: " ")
        case let a as [Any]:
            return "[" + a.map { stringify($0) }.joined(separator: ", ") + "]"
        case let d as [String: Any]:
            let parts = d
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(stringify($0.value))" }
            return "{" + parts.joined(separator: ", ") + "}"
        default:
            return String(describing: value)
        }
    }
}
