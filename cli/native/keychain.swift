import Foundation
import Security

// Commands and credentials arrive over stdin, never process arguments.
do {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let input = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let operation = input["operation"] as? String else { exit(2) }
    let testID = (input["test_namespace"] as? String).flatMap(UUID.init(uuidString:))
    let service = testID.map { "dev.pushnow.cli.test.\($0.uuidString)" } ?? "dev.pushnow.cli"
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service, kSecAttrAccount as String: "default"]
    if operation == "read" {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let code = SecItemCopyMatching(request as CFDictionary, &result)
        if code == errSecItemNotFound { print("null"); exit(0) }
        guard code == errSecSuccess, let secret = result as? Data else { exit(3) }
        FileHandle.standardOutput.write(secret)
    } else if operation == "write" {
        guard let value = input["value"] else { exit(2) }
        let secret = try JSONSerialization.data(withJSONObject: value)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: secret] as CFDictionary)
        if updated == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = secret
            request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { exit(3) }
        } else if updated != errSecSuccess { exit(3) }
    } else if operation == "delete" {
        let code = SecItemDelete(query as CFDictionary)
        guard code == errSecSuccess || code == errSecItemNotFound else { exit(3) }
    } else { exit(2) }
} catch { exit(2) }
