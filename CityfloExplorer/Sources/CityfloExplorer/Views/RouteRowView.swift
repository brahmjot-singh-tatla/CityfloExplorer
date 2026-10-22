import SwiftUI

struct RouteRowView: View {
    let route: Route

    private var availableSeats: Int? {
        let trip = route.trips.first
        guard let trip else { return nil }
        return max(0, route.seatsTotal - trip.seatsBooked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(route.displayName)
                    .font(.headline)
                Spacer()
                if !route.active {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            HStack(spacing: 8) {
                if let corridor = route.corridor {
                    Label(corridor.capitalized, systemImage: "tram")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Unknown corridor", systemImage: "tram")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let seats = availableSeats {
                    Label("\(seats) seats left", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(seats < 5 ? .orange : .secondary)
                }
            }

            Text("\(route.trips.count) trip\(route.trips.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
