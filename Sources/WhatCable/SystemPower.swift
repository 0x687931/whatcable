import Foundation
import IOKit.ps

struct SystemPower {
    let watts: Int?

    static func currentAdapter() -> SystemPower? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as NSDictionary? else {
            return nil
        }

        return SystemPower(
            watts: (details["Watts"] as? NSNumber)?.intValue
        )
    }
}
