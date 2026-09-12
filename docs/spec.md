# Life is a Game. Product spec

One page. If a feature is not here, it is not in phase 1.

## The job

The user has things they want to become better at or finish for their own reasons, and life keeps making them forget. The app holds those intentions as Paths the user writes in their own words, and surfaces one of them when the moment is right. It never nags, never scores, and never loses progress.

Said as a job story. When I have a free evening or a weekend morning, I want the one thing I meant to do to appear in front of me as an objective, so I do it instead of scrolling, and so I can see later that I am evolving.

## Who it is for

The owner, first. Then anyone with interests that are not their job. The app does not know what those interests are. Music is a hobby for one user and work for another. The Path's role carries that difference, not the app.

## Non-goals for phase 1

- No accounts, cloud, sync, sharing, or App Store.
- No work task management. Work is a role the user may choose, not a feature.
- No XP, points, coins, HP, levels, streaks, leaderboards, avatars, pets, or shop.
- No preset trees. Templates are editable examples, not curricula.
- No canvas or graph editor. Authoring is a text field.
- No cloud AI. The on-device model may help write a Path down (behind a Settings toggle) and only writes what the user said, in the user's words. The owner's coding agent can author nodes through JSON import in phase 2.

## The six things the app knows

- Path. A thing being evolved. Name, identity label ("guitarist"), glyph (SF Symbol), role, ordered milestones, nodes.
- Role. `hobby`, `craft`, `decision`, `lab`, `work`. Sets default cue windows, surfacing cadence, and voice.
- Node. `quest` (one-shot) or `practice` (repeatable, never done). Optional single `after` blocker. Has a cue.
- Milestone. A sentence describing a state of the world. Ticked by hand. Order gives the Path its stages.
- Cue. When a node may surface. Phase 1 supports weekday, weekend, morning, evening, anytime, and an exact date.
- LogEntry. What happened, when, optional photo. The proof and the memory.

## Surfacing rules

1. One objective per day at most, across all Paths.
2. Only nodes whose cue is true for that day and window.
3. A node never repeats within 7 days of last being surfaced.
4. A node with an unfinished `after` blocker is not eligible.
5. Paths whose role is silent on that day type (work on weekends, hobby on weekday mornings) are skipped.
6. Roles rotate. If yesterday's objective came from Path A, another eligible Path is preferred today.
7. A node skipped with Not now twice in a row is paused until the user reopens it.
8. A node untouched for 30 days is surfaced once as "still want this?". Silence archives it as "path not taken".
9. A Path with every milestone ticked is "evolved" and stops surfacing.
10. Decision-role Paths surface once a week until their deadline, then daily in the final three days.

## Screens

Today, Paths, Path detail, New path (typed, or talked through with the on-device model), Capture, Milestone celebration, Settings. See `screens-and-flows.md`.

## Voice

Quest log, not to-do list. "New objective" not "Reminder". "Path not taken" not "deleted". "Evolved" not "completed". Full strings in `copy-deck.md`.

## Design rules from the research

- Self-authored content. The user writes every node and milestone. Templates are starting text, deletable in one tap.
- Rewards are informational, never expected. A milestone tick is a celebration of a fact, not a payout.
- Progress cannot be lost. Nothing decays, nothing resets.
- Cue-based surfacing beats clock alarms. Ask "when could I do this" at capture, not "at what time".
- Low volume. One per day. A muted app is a dead app.
- Finishing is a win. Evolved Paths go quiet and stay visible as history.

## Success metric for the four-week gate

Count of Done actions and milestones ticked. Not opens, not nodes authored. One real milestone by week four or stop.

## Platform

iOS 26 or later, Swift, SwiftUI, one JSON document for storage, UserNotifications, Foundation Models on device. Free Apple ID for now. Built on GitHub Actions macOS runners, installed from Xcode on a Mac until Splice works from the Linux laptop.
