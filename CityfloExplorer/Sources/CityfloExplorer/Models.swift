import Foundation

// MARK: - Raw decodable types (tolerant of data quality issues)

struct RoutesResponse: Decodable {
    let generatedAt: String
    let city: String
    let clientConfig: ClientConfig
    let routes: [Route]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case city
        case clientConfig = "client_config"
        case routes
    }
}

struct ClientConfig: Decodable {
    let resultsPageSize: Int
    let logSearchQueriesVerbatim: Bool

    enum CodingKeys: String, CodingKey {
        case resultsPageSize = "results_page_size"
        case logSearchQueriesVerbatim = "log_search_queries_verbatim"
    }
}

struct Route: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let corridor: String?      // R-119 has no corridor
    let active: Bool
    let seatsTotal: Int
    let trips: [Trip]

    // Display name falls back to id when name is empty (R-120)
    var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? id : name }

    var availabilityNote: String? {
        guard active else { return "Route inactive" }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, corridor, active
        case seatsTotal = "seats_total"
        case trips
    }
}

struct Trip: Decodable, Identifiable, Hashable, Sendable {
    let tripId: String
    let departure: Date?
    let arrival: Date?
    let seatsBooked: Int
    let onTimePct: Double?    // T-1018 sends this as a string
    let status: String

    var id: String { tripId }

    // T-1035: arrival before departure
    var hasInvalidTiming: Bool {
        guard let d = departure, let a = arrival else { return false }
        return a <= d
    }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case departure, arrival
        case seatsBooked = "seats_booked"
        case onTimePct = "on_time_pct"
        case status
    }

    // Custom init to handle on_time_pct being either Double or String
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tripId = try c.decode(String.self, forKey: .tripId)
        seatsBooked = try c.decode(Int.self, forKey: .seatsBooked)
        status = try c.decode(String.self, forKey: .status)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String) -> Date? {
            iso.date(from: str) ?? isoBasic.date(from: str)
        }

        if let dStr = try? c.decode(String.self, forKey: .departure) {
            departure = parseDate(dStr)
        } else {
            departure = nil
        }
        if let aStr = try? c.decode(String.self, forKey: .arrival) {
            arrival = parseDate(aStr)
        } else {
            arrival = nil
        }

        // on_time_pct can be Double or String
        if let d = try? c.decode(Double.self, forKey: .onTimePct) {
            onTimePct = d
        } else if let s = try? c.decode(String.self, forKey: .onTimePct), let d = Double(s) {
            onTimePct = d
        } else {
            onTimePct = nil
        }
    }
}
