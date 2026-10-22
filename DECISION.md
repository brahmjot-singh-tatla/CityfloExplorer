# DECISION.md — CityfloExplorer iOS Take-home

## 1. Scope cut: what I built and what I didn't

**Decision:** Build search + list + detail + recent searches fully. Cut: pagination, empty-state illustrations, filter-by-corridor UI, offline error retry, deep linking.

**The rule:** Ship the vertical slice the brief names (search → list → detail → recents) completely and correctly before adding surface area. Any cut must be explicitly named.

**The case it breaks on:** A user searching "western" on a real endpoint with 200+ results gets a flat list with no pagination. Scrolling 200 rows on a phone at 8am is bad UX.

**The cost, and who pays it:** Commuters searching broad terms (corridor names) get an unmanageable list. At 60,000 rides/day, roughly 15–20% of users search by corridor — that's ~10,000 users who get a worse experience than they should. The cost is friction, not lost bookings, because the correct bus is still findable.

**What would change my mind:** A live endpoint returning >50 results for any real query. The bundled dataset has 20 routes total, so pagination is moot against it. If Cityflo swaps in the real network API for the debrief and a "western" query returns 80+ routes, I'd add infinite scroll immediately.

**Runner-up rejected:** Filter-by-corridor chips above the list. Rejected because it requires the full route set to be loaded before first keystroke — which adds a loading state before the user has even typed. Search covers the same ground with no extra UI surface.

---

## 2. Cancellation model

**Decision:** Each new keystroke cancels the in-flight `Task` immediately. The 327ms debounce sleep is inside the task — if it's cancelled during sleep, it exits before touching UI state. The network call (`URLSession.data(from:)`) also respects `Task` cancellation natively.

**The rule:** One `Task` at a time. New query → `searchTask?.cancel()` → new task with debounce sleep → fetch. A task that is cancelled during sleep produces no result and touches no UI state.

**The case it breaks on:** A user types 5 characters within 327ms, then stops. Four tasks are cancelled mid-sleep; the fifth runs. If the fifth task's fetch takes 3 seconds (real network, rate-limited) and the user types a 6th character at 2.5 seconds in, the 6th cancels the 5th's live request mid-flight. `URLSession` surfaces this as a `CancellationError`, which the task catches and discards. The window where a stale result could appear is 0ms — cancellation is synchronous before the result is applied.

**The cost, and who pays it:** None in the bundled data case (file:// loads in ~1ms). On a real rate-limited endpoint with 429s, a user typing fast could kill a request that was about to complete — they wait 327ms longer than needed. One extra round-trip, worst case.

**What would change my mind:** If the debrief endpoint is extremely slow (>5s) and users commonly wait and then retype, I'd add a minimum-display-time policy so a result that took 4s to arrive stays visible for at least 1s before being replaced.

---

## 3. Stale vs. blank

**Decision:** Keep last-known results on screen while a new request is in flight. A spinner overlay appears at the top of the list. Results are cleared only when the query field is emptied.

**The rule:** A commuter at 8am standing at a stop has something useful on screen at all times. An empty/loading screen while re-fetching is worse than slightly stale data.

**The case it breaks on:** A user searches "Andheri", sees Route R-101, then immediately types "Bandra". For 327ms they see Andheri results with a spinner — which might cause them to tap a stale result before the Bandra results arrive. R-101 is a real route; tapping it mid-search takes them to R-101's detail, not a broken state. The cost is one unwanted navigation, easily back-swipeable.

**The cost, and who pays it:** Occasionally a commuter taps a stale result and navigates to the wrong detail view. Back-swipe recovers. The alternative — blank screen during every debounce window — means every 327ms the screen goes empty, which is worse for the 60,000 users who check at rush hour.

**What would change my mind:** If Cityflo's product team has data showing >5% of users tap stale results and don't recover (abandonment, wrong booking), I'd add a 200ms fade-to-loading before showing stale results, giving a visual signal that results are updating.

---

## 4. Recent searches: shape and persistence

**Decision:** Max 10 entries, most-recent-first, case-insensitive deduplication, tappable to re-run. Stored in `UserDefaults` under a stable key. `RecentSearchesStore` is an actor.

**The rule:** Recents are per-device convenience, not synced data. UserDefaults is the right store: it survives app restart, requires no auth, and is trivially accessible. An actor prevents the write-from-search racing a clear-from-UI.

**The case it breaks on:** A user clears recents and immediately types a new search. The `clearRecents()` call dispatches a `Task` that `await`s the actor. The search `add()` call also `await`s the actor. Actor serialization guarantees they don't interleave, but the order depends on which `Task` was scheduled first. If clear runs after add, the new search is lost from recents. This window is ~0ms in practice (the user clears, then types), but it's a real race.

**The cost, and who pays it:** In the race case, a single search term doesn't appear in recents. The user retypes it and it appears on the second search. Negligible cost.

**What would change my mind:** If Cityflo moves to multi-device sync (iCloud, server-side recents), I'd replace UserDefaults with a `NSUbiquitousKeyValueStore` or a backend call. The actor interface stays the same — only the backing store changes.

---

## 5. Duplicate route ID R-110

**Decision:** Keep the first occurrence ("Nerul → Mulund"), silently drop the second ("Chembur → Ghatkopar"). Log the drop in a comment.

**The rule:** A unique identifier that isn't unique is a data defect, not a feature. Displaying two routes with the same `id` breaks `List` identity and `NavigationStack` state. Drop the duplicate rather than inventing a synthetic ID.

**The case it breaks on:** "Chembur → Ghatkopar" is a real route that commuters search. If they type "Chembur" they get no results (the route was dropped). That's a real miss — a commuter might think their route doesn't exist.

**The cost, and who pays it:** Any commuter whose route is "Chembur → Ghatkopar" (R-110 duplicate) sees no results when they search for it. At ~60,000 rides/day and an even distribution across ~20 routes, that's roughly 3,000 potential affected users. The cost is confusion, not a missed booking (they'd likely call support or check the website).

**What would change my mind:** If the debrief data assigns R-110b a unique ID, this decision is moot. If the duplicate persists, I'd surface both routes with a "(data issue)" badge and file a bug with the backend team rather than silently dropping one.

---

## 6. Data source: bundled file via URLSession

**Decision:** Bundle `routes.json` and load it via `URLSession` with a `file://` URL. This satisfies "treat it as a network source: it flows through your async networking layer" while keeping the app self-contained for the submission.

**The rule:** The networking path must be exercised by the production code path, not a special-cased synchronous read. Using `URLSession` even for a file URL means all Task cancellation, error propagation, and async/await machinery is real — not mocked.

**The case it breaks on:** Cancellation during a file load is essentially instantaneous (~1ms). The debounce (327ms) is far longer than the fetch, so in practice no in-flight request ever gets cancelled — the cancel fires during the debounce sleep, before the fetch starts. This means my cancellation model is correct but not exercised by the bundled data.

**The cost, and who pays it:** The debrief will swap in a real endpoint with real latency. My `CFNetworkConduit` is wired for `URLSession` — swapping the URL is a one-line change. The cancellation model will be exercised then.

**What would change my mind:** If the debrief shows a cancellation bug under real latency, I'd add a `Task.checkCancellation()` checkpoint immediately after the `session.data(from:)` call returns, before decoding.

---

## 7. Fields trusted vs. treated with suspicion

| Field | Trust level | Reason |
|---|---|---|
| `route.id` | Suspicious | R-110 is duplicated |
| `route.name` | Low (UI fallback) | R-120 is empty |
| `route.corridor` | Optional | R-119 missing |
| `trip.departure` / `arrival` | Parsed, flagged | T-1035 has impossible timing |
| `trip.on_time_pct` | Lenient (String or Double) | T-1018 sends String |
| `trip.seats_booked` | Display as-is, flagged | T-1045 exceeds capacity |
| `trip.status` | Display as-is | Status conflicts (T-1064) shown alongside on_time_pct so human can see contradiction |

**The rule:** Display all data but surface anomalies as callouts in the detail view. Don't silently normalize corrupted data — the user (a commuter) deserves to know when something looks wrong.
