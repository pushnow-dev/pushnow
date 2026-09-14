struct InMemoryFeatureRepository: FeatureRepository {
    func loadFeaturedItems() async throws -> [FeatureItem] {
        try await Task.sleep(nanoseconds: 120_000_000)
        return FeatureItem.samples
    }
}
