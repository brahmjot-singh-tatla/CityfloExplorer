import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {

    // MARK: Published state
    var query: String = "" {
        didSet { scheduleSearch() }
    }
    var results: [Route] = []
    var recentSearches: [String] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // MARK: Private
    private let conduit = CFNetworkConduit()
    private let recentsStore = RecentSearchesStore()
    private var allRoutes: [Route] = []
    private var searchTask: Task<Void, Never>? = nil

    // Debounce: exactly 327 ms as specified
    private let debounceNanoseconds: UInt64 = 327_000_000

    // MARK: Lifecycle

    func onAppear() {
        Task {
            await loadRecents()
            await loadAllRoutes()
        }
    }

    // MARK: Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let currentQuery = query

        searchTask = Task {
            do {
                // Debounce: wait exactly 327 ms before firing
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return // Task was cancelled during debounce — discard
            }

            guard !Task.isCancelled else { return }

            await performSearch(query: currentQuery)
        }
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        // If routes aren't loaded yet, load them now
        if allRoutes.isEmpty {
            await loadAllRoutes()
        }

        guard !Task.isCancelled else { return }

        let matched = filter(routes: allRoutes, query: trimmed)
        results = matched
        isLoading = false

        if matched.isEmpty {
            errorMessage = "No routes matched \"\(trimmed)\""
        }

        // Persist the search
        await recentsStore.add(trimmed)
        await loadRecents()
    }

    func submitSearch(_ q: String) {
        query = q
    }

    // MARK: Data loading

    private func loadAllRoutes() async {
        do {
            let response = try await conduit.fetchRoutes()
            // Deduplicate by id: keep first occurrence (R-110 appears twice)
            var seen = Set<String>()
            allRoutes = response.routes.filter { seen.insert($0.id).inserted }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Failed to load routes: \(error.localizedDescription)"
            }
        }
    }

    private func loadRecents() async {
        recentSearches = await recentsStore.all()
    }

    func clearRecents() {
        Task {
            await recentsStore.clear()
            await loadRecents()
        }
    }

    // MARK: Filtering

    private func filter(routes: [Route], query: String) -> [Route] {
        let q = query.lowercased()
        return routes.filter { route in
            route.displayName.lowercased().contains(q)
            || (route.corridor ?? "").lowercased().contains(q)
            || route.id.lowercased().contains(q)
            || route.trips.contains { $0.tripId.lowercased().contains(q) }
        }
    }
}
