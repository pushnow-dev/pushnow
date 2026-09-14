import Foundation

enum AppError: Error, Equatable, LocalizedError, Sendable {
    case missingConfiguration(String)
    case paymentNotConfigured
    case repositoryUnavailable
    case underlying(String)

    init(_ error: Error) {
        if let appError = error as? AppError {
            self = appError
        } else {
            self = .underlying(error.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            "缺少配置：\(key)"
        case .paymentNotConfigured:
            "支付服务尚未完成配置"
        case .repositoryUnavailable:
            "数据服务暂时不可用"
        case .underlying(let message):
            message
        }
    }
}
