import SwiftUI

struct SearchView: View {
    @State private var vm = SearchViewModel()
    @State private var selectedRoute: Route? = nil

    var body: some View {
        @Bindable var vmBindable = vm
        NavigationStack {
            Group {
                if vm.query.isEmpty {
                    recentsSection
                } else {
                    resultsList
                }
            }
            .navigationTitle("Cityflo Mumbai")
            .searchable(text: $vmBindable.query, prompt: "Route, stop, or corridor…")
            .navigationDestination(item: $selectedRoute) { route in
                RouteDetailView(route: route)
            }
            .onSubmit(of: .search) {
                vm.submitSearch(vm.query)
            }
        }
        .onAppear { vm.onAppear() }
    }

    // MARK: Recents

    @ViewBuilder
    private var recentsSection: some View {
        if vm.recentSearches.isEmpty {
            ContentUnavailableView(
                "Search Mumbai routes",
                systemImage: "bus",
                description: Text("Type a route name, stop, or corridor")
            )
        } else {
            List {
                Section {
                    ForEach(vm.recentSearches, id: \.self) { recent in
                        Button {
                            vm.submitSearch(recent)
                        } label: {
                            Label(recent, systemImage: "clock")
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear") { vm.clearRecents() }
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        ZStack {
            if vm.isLoading && vm.results.isEmpty {
                ProgressView("Searching…")
            } else if let err = vm.errorMessage, vm.results.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text(err)
                )
            } else {
                List(vm.results) { route in
                    Button {
                        selectedRoute = route
                    } label: {
                        RouteRowView(route: route)
                    }
                    .buttonStyle(.plain)
                }
                .overlay(alignment: .top) {
                    if vm.isLoading {
                        ProgressView()
                            .padding(8)
                            .background(.thinMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
}
