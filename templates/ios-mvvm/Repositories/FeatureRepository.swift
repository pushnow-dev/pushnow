protocol FeatureRepository: Sendable {
    func loadFeaturedItems() async throws -> [FeatureItem]
}
