import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: ViewState<[FeatureItem]> = .idle

    var items: [FeatureItem] {
        if case .loaded(let items) = state {
            return items
        }
        return []
    }

    func load(repository: any FeatureRepository) async {
        state = .loading

        do {
            let items = try await repository.loadFeaturedItems()
            state = .loaded(items)
        } catch {
            state = .failed(AppError(error))
        }
    }
}
