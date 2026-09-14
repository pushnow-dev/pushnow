import Foundation

#if DEBUG
@MainActor
enum PaymentDiagnostics {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--payment-diagnostics") }

    static func emit(service: RevenueCatService, signedIn: Bool, phase: String, error: Error? = nil) {
        guard enabled else { return }
        var result: [String: Any] = [
            "phase": phase, "configured": service.isConfigured, "signedIn": signedIn,
            "sdkPlan": service.entitlementState.membershipPlan.rawValue,
            "serverPlan": service.serverMembershipPlan?.rawValue ?? "unknown",
            "serverSyncPending": service.serverSyncPending,
            "packages": service.offers.map {
                ["packageID": $0.packageID, "productID": $0.productID, "price": $0.localizedPrice]
            }
        ]
        if let error {
            let value = error as NSError
            result["errorDomain"] = value.domain
            result["errorCode"] = value.code
            if let payment = error as? PaymentError { result["reason"] = String(describing: payment) }
            if error as? AppError == .paymentNotConfigured { result["reason"] = "payment_not_configured" }
        } else if !signedIn {
            result["reason"] = "sign_in_required"
        }
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return }
        FileHandle.standardOutput.write(Data("PUSHNOW_PAYMENT_DIAGNOSTICS \(json)\n".utf8))
    }
}
#endif
