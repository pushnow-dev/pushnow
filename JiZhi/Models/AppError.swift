import Foundation
import OSLog

enum AppError: Error, Equatable, LocalizedError, Sendable {
    case missingConfiguration(String)
    case paymentNotConfigured
    case repositoryUnavailable
    case underlying(String)

    init(_ error: Error) {
        if let appError = error as? AppError {
            self = appError
        } else if error is APIStatusError || error is PaymentError || error is SecureFailure {
            self = .underlying(error.localizedDescription)
        } else {
            let value = error as NSError
            Logger(subsystem: "com.createitv.pushnow", category: "errors")
                .error("Request failed: domain=\(value.domain, privacy: .public), code=\(value.code)")
            let key: String.LocalizationValue = value.domain == NSURLErrorDomain
                ? "Check your internet connection and try again."
                : "The service is temporarily unavailable. Please try again later."
            self = .underlying(AppLocalization.text(key, language: AppLocalization.language))
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingConfiguration, .repositoryUnavailable:
            AppLocalization.text("The service is temporarily unavailable. Please try again later.", language: AppLocalization.language)
        case .paymentNotConfigured:
            AppLocalization.text("Subscriptions are temporarily unavailable. Please try again.", language: AppLocalization.language)
        case .underlying(let message):
            message
        }
    }
}
