import SwiftUI

struct RouteDetailView: View {
    let route: Route

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        List {
            // Route header
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(route.displayName)
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        if let corridor = route.corridor {
                            Label(corridor.capitalized, systemImage: "tram")
                        } else {
                            Label("Corridor unknown", systemImage: "tram")
                                .foregroundStyle(.secondary)
                        }
                        Label("\(route.seatsTotal) seats", systemImage: "seat")
                        if !route.active {
                            Label("Inactive", systemImage: "xmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Route \(route.id)")
            }

            // Trips
            Section {
                ForEach(route.trips) { trip in
                    tripRow(trip)
                }
            } header: {
                Text("Trips (\(route.trips.count))")
            }
        }
        .navigationTitle(route.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.tripId)
                    .font(.headline)
                Spacer()
                statusBadge(trip)
            }

            HStack(spacing: 16) {
                if let dep = trip.departure {
                    Label(timeFormatter.string(from: dep), systemImage: "arrow.right.circle")
                        .font(.caption)
                }
                if let arr = trip.arrival {
                    Label(timeFormatter.string(from: arr), systemImage: "flag.checkered")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)

            if trip.hasInvalidTiming {
                Label("Data issue: arrival before departure", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                let available = max(0, route.seatsTotal - trip.seatsBooked)
                // T-1045: seats_booked can exceed seats_total
                if trip.seatsBooked > route.seatsTotal {
                    Label("Overbooked (\(trip.seatsBooked)/\(route.seatsTotal))", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Label("\(available) available", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(available < 5 ? .orange : .secondary)
                }

                if let pct = trip.onTimePct {
                    Label(String(format: "%.0f%% on-time", pct), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(pct >= 80 ? .green : .orange)
                } else {
                    Label("On-time data unavailable", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(_ trip: Trip) -> some View {
        let isDelayed = trip.status == "delayed"
        Text(trip.status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption.bold())
            .foregroundStyle(isDelayed ? .orange : .green)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isDelayed ? Color.orange : Color.green).opacity(0.15), in: Capsule())
    }
}
