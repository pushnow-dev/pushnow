import Darwin
import Foundation
import UIKit

enum DeviceDisplayName {
    @MainActor
    static func current(existingName: String?, installationID: String) -> String {
        compose(existingName: existingName, systemName: UIDevice.current.name,
            hardwareIdentifier: hardwareIdentifier, family: UIDevice.current.model,
            installationID: installationID)
    }

    static func compose(existingName: String?, systemName: String, hardwareIdentifier: String,
                        family: String, installationID: String) -> String {
        if let existingName { return existingName }
        let model = modelNames[hardwareIdentifier] ?? "\(family) \(hardwareIdentifier)"
        let name = systemName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let genericNames = ["", "iphone", "ipad", "ipod touch", family.lowercased(), model.lowercased()]
        if genericNames.contains(name.lowercased()) {
            return limited("\(model) (\(installationID.prefix(6).uppercased()))", units: 80)
        }
        if name.range(of: model, options: .caseInsensitive) != nil {
            return limited(name, units: 80)
        }
        let suffix = " (\(limited(model, units: 50)))"
        return limited(name, units: 80 - suffix.utf16.count) + suffix
    }

    private static var hardwareIdentifier: String {
        #if targetEnvironment(simulator)
        if let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return identifier
        }
        #endif
        var system = utsname()
        guard uname(&system) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    private static func limited(_ value: String, units: Int) -> String {
        var result = String(value.prefix(units))
        while result.utf16.count > units { result.removeLast() }
        return result
    }

    // Hardware identifiers are public model codes, not device serial numbers.
    // Cross-checked against DeviceKit's model registry; unknown models retain their exact code.
    private static let modelNames = [
        "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR", "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air", "iPhone18,5": "iPhone 17e"
    ]
}
