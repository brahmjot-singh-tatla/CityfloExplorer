import Foundation

// CFNetworkConduit: actor that owns all URLSession calls.
// Decision: actor isolation guarantees no data races on session/config state.
// The bundled routes.json is loaded via a file:// URL so it flows through the
// async networking layer (URLSession), not a synchronous read.
actor CFNetworkConduit {

    private let session: URLSession
    private let dataURL: URL

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)

        // Resolve bundle URL for routes.json at init time (sync, safe inside actor init)
        if let url = Bundle.main.url(forResource: "routes", withExtension: "json") {
            dataURL = url
        } else {
            // Fallback: should never happen in a correctly built target
            dataURL = URL(fileURLWithPath: "routes.json")
        }
    }

    // Fetches and decodes the routes payload.
    // Cancellation: URLSession respects Task cancellation on data(from:).
    func fetchRoutes() async throws -> RoutesResponse {
        let (data, response) = try await session.data(from: dataURL)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CFError.httpError(http.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(RoutesResponse.self, from: data)
    }
}

enum CFError: Error, LocalizedError {
    case httpError(Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Server returned \(code)"
        case .noResults: return "No routes found"
        }
    }
}
