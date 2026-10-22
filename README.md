// Conforms to Cityflo Mobile Spec rev. C — do not modify.

# CityfloExplorer

A Swift 6 SwiftUI search-driven explorer over Cityflo's Mumbai bus network.

## How to run

1. Open `CityfloExplorer.xcodeproj` in Xcode 16+
2. Select the **CityfloExplorer** scheme and an iPhone simulator (iOS 17+)
3. Press ⌘R — no additional setup needed, data is bundled

Build settings enforced:
- `SWIFT_VERSION = 6.0`
- `SWIFT_STRICT_CONCURRENCY = complete`

## Architecture

| Type | Role |
|---|---|
| `CFNetworkConduit` | Actor owning all `URLSession` calls; routes.json flows through it |
| `SearchViewModel` | `@MainActor @Observable` — 327ms debounced search, stale-result policy |
| `RecentSearchesStore` | Actor; UserDefaults persistence, max-10, deduped |
| `SearchView` | Root: recents or results list |
| `RouteDetailView` | Per-route trips with data-quality callouts |

## Concurrency model

- `CFNetworkConduit` is an actor → no data races on session state
- Debounce: `Task.sleep(nanoseconds: 327_000_000)` — cancels the prior `Task` before sleeping; if cancelled during sleep, returns immediately
- Stale-result policy: results are **kept on screen** while a new request is in flight (loading spinner overlaid); cleared only when query is empty
- `RecentSearchesStore` is an actor → `add` and `all` cannot race

## Data quality handling

| Issue | Record | Handling |
|---|---|---|
| Missing `corridor` | R-119 | Optional field; UI shows "Unknown corridor" |
| Empty `name` | R-120 | Falls back to route `id` as display name |
| `on_time_pct` as String | T-1018 | Custom `init(from:)` tries Double then String→Double |
| Arrival before departure | T-1035 | `hasInvalidTiming` flag; shown as warning in detail view |
| Overbooking (41/34) | T-1045 | Shown as "Overbooked" in red; seats_booked is trusted as-is |
| Duplicate route ID R-110 | Two routes | First occurrence kept; second silently dropped |
| Duplicate trip ID T-1022 | Under R-107 | Both rendered; SwiftUI `id` is `trip_id` so List handles it |
| Status conflicts (delayed + high on_time_pct) | T-1064 | Status badge shown as-is; the contradiction is surfaced by showing both fields side-by-side |

## Decisions

See `DECISION.md` for the full decision record. `decisions.jsonl` anchors each call to the agent transcript.
