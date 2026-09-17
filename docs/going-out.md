# Going out today

Implemented in source on 2026-09-17. Device build and notification testing remain outstanding.

## Behavior

- Capture and the quest editor have an Outside home toggle. Older saved nodes without this optional field remain compatible.
- Today has a Going out today toggle. It persists across launches for the current local calendar day and resets on the next day (on activation, or within 30 seconds while Today remains open).
- When enabled, eligible outside quests appear once in a While you're out section above every Today filter, including Routine. A steady gold outline and glow, plus an Outside home label, distinguish them. Existing Work backgrounds remain.
- Outside quests stay in the normal lists when the mode is off. Turning the mode on does not bypass dates, blockers, resting/evolved paths or the weekday-only Work rule.
- Enabling the mode with eligible quests opens the reminder sheet. The user chooses a future time today and explicitly sets a reminder. Closing the sheet leaves highlighting enabled without scheduling an alert.
- One local notification summarizes up to five titles, with a count and a prompt to open Today for longer lists. Tapping it selects Today. No GPS, background tracking or repeated alerts.
- The pending reminder refreshes when relevant quests change; completing all eligible errands or turning the mode off removes it. Normal daily-objective notifications use separate identifiers.
- Permission denial and scheduling errors are shown in the interface. iOS notification settings and Focus control actual delivery; this is not an undismissable pinned notification or a Live Activity.

## Validation

27 engine tests pass, including three new tests covering legacy decoding/flag round-trip, due dates/blockers/completion/resting paths, routine exclusion, and Work weekday rules. Swift source parsing and diff whitespace checks pass on Linux. This does not replace an Xcode type-check/build or device tests.

On iPhone/simulator verify: flag and edit an outside quest; toggle the mode under each Today filter; check Work and non-Work contrast; set a reminder a few minutes ahead; background/close the app; tap the notification from Paths; complete/change/remove errands before delivery; cancel the reminder; deny permission; relaunch; cross midnight; confirm normal daily notifications still work. Confirm no duplicate or stale notification after rapid edits.

Apple reference: [Scheduling local notifications](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html). iOS handles delivery of scheduled local notifications while the app is backgrounded or not running.

The requested pstack/potato mode was unavailable in the session; no such tool was invoked.
