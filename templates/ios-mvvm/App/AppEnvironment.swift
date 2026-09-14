import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let configuration: AppConfiguration
    let featureRepository: any FeatureRepository
    let revenueCatService: RevenueCatService
    let systemService: SystemService

    init(
        configuration: AppConfiguration,
        featureRepository: any FeatureRepository,
        revenueCatService: RevenueCatService,
        systemService: SystemService
    ) {
        self.configuration = configuration
        self.featureRepository = featureRepository
        self.revenueCatService = revenueCatService
        self.systemService = systemService
    }

    static func live() -> AppEnvironment {
        let configuration = AppConfiguration.default
        let revenueCatService = RevenueCatService()
        if let apiKey = configuration.revenueCatAPIKey {
            revenueCatService.configure(apiKey: apiKey)
        }

        return AppEnvironment(
            configuration: configuration,
            featureRepository: InMemoryFeatureRepository(),
            revenueCatService: revenueCatService,
            systemService: .live
        )
    }

    static func preview() -> AppEnvironment {
        AppEnvironment(
            configuration: .default,
            featureRepository: InMemoryFeatureRepository(),
            revenueCatService: RevenueCatService(entitlementState: .previewPro),
            systemService: .preview
        )
    }
}
