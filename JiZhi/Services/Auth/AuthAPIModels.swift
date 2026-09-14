import Foundation
import UIKit

struct StartEmailAuthRequest: Encodable {
    var email: String
    var locale: String
    var timezone: String
    var client: AuthClientContext
}

struct VerifyEmailAuthRequest: Encodable {
    var email: String
    var code: String
    var client: AuthClientContext
}

struct PasswordLoginRequest: Encodable {
    var email: String
    var password: String
    var client: AuthClientContext
}

struct SetPasswordRequest: Encodable {
    var password: String
}

struct RefreshSessionRequest: Encodable {
    var refreshToken: String
}

struct LogoutRequest: Encodable {
    var refreshToken: String?
}

struct StartEmailAuthResponse: Decodable {
    var status: String
    var expiresInSeconds: Int
}

struct AuthSessionResponse: Decodable {
    var user: APIUser
    var accessToken: String
    var refreshToken: String
    var expiresInSeconds: Int
}

struct MeResponse: Decodable {
    var user: APIUser
}

struct APIUser: Decodable {
    var id: String
    var email: String
    var emailVerifiedAt: String?
    var hasPassword: Bool
    var passwordSetAt: String?
}

struct AuthClientContext: Encodable {
    var platform: String
    var deviceId: String
    var appVersion: String

    @MainActor
    static var current: AuthClientContext {
        AuthClientContext(
            platform: "ios",
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios-device",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        )
    }
}
