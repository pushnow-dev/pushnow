import Foundation

struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func postJSON<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder.api.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    func getJSON<Response: Decodable>(_ path: String, accessToken: String) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    func getJSONWithStatus<Response: Decodable>(_ path: String, accessToken: String) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    func patchJSON<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.api.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    func putJSON<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.api.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    func postJSONNoResponse<Body: Encodable>(
        _ path: String,
        body: Body,
        accessToken: String
    ) async throws {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.api.encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func deleteNoResponse(_ path: String, accessToken: String) async throws {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { throw AppError.repositoryUnavailable }
        guard (200..<300).contains(response.statusCode) else {
            let error = APIStatusError(statusCode: response.statusCode, data: data)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--api-diagnostics") {
                let path = (response.url?.path ?? "").replacingOccurrences(
                    of: "[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}", with: ":id", options: .regularExpression)
                let code = error.code.flatMap { $0.range(of: "^[a-z_]{1,80}$", options: .regularExpression) != nil ? $0 : nil } ?? "unknown"
                print("PUSHNOW_API_ERROR status=\(response.statusCode) path=\(path) code=\(code)")
            }
            #endif
            throw error
        }
    }

    private func url(for path: String) -> URL {
        if let url = URL(string: path, relativeTo: baseURL)?.absoluteURL {
            return url
        }
        return baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

struct APIStatusError: LocalizedError, Sendable {
    let statusCode: Int
    let code: String?

    init(statusCode: Int, data: Data = Data()) {
        self.statusCode = statusCode
        self.code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.code
    }

    private struct ErrorBody: Decodable { let code: String }

    // Only known public codes become specific messages; server text may contain internal details.
    var messageKey: String {
        switch code {
        case "invalid_credentials": return "Email or password is incorrect. You can also sign in with a verification code."
        case "session_expired", "session_mismatch", "missing_bearer_token": return "Your session has expired. Please sign in again."
        case "auth_failed", "auth_code_expired": return "The verification code is incorrect or expired. Request a new code."
        case "invalid_auth_code": return "Enter a valid verification code."
        case "invalid_email": return "Enter a valid email address."
        case "invalid_password": return "Password must contain 8 to 128 characters."
        case "weak_password": return "Password must contain letters and numbers."
        case "email_already_used": return "This email is already linked to another account."
        case "auth_rate_limited": return "Too many requests. Please try again later."
        case "email_delivery_failed": return "The verification email could not be sent. Please try again later."
        default: break
        }
        switch statusCode {
        case 400, 422: return "Check the information you entered and try again."
        case 401: return "Your session has expired. Please sign in again."
        case 403: return "You do not have permission to perform this action."
        case 404: return "This content is no longer available."
        case 409: return "The data has changed. Refresh and try again."
        case 413: return "The submitted content is too large."
        case 429: return "Too many requests. Please try again later."
        default: return "The service is temporarily unavailable. Please try again later."
        }
    }

    var errorDescription: String? {
        AppLocalization.text(String.LocalizationValue(messageKey), language: AppLocalization.language)
    }
}
