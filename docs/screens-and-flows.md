# Screens and flows

Six screens. Navigation is a tab bar with two tabs, Today and Paths. Everything else is a sheet or a push from those two.

## Screen inventory

| Screen | Purpose | Entry | Exit |
|---|---|---|---|
| Today | Show today's one objective, or the reason there is none. Done / Not now / Too big. | Tab, notification tap, widget tap | Capture sheet, Path detail |
| Paths | List of Paths with glyph, identity, milestone progress as ticks, quiet state (evolved, paused). | Tab | Path detail, Capture (new Path) |
| Path detail | Milestones as an ordered strip, nodes grouped as quests and practices, log entries below. Edit in place. | Paths list, Today card title | Capture (new node), Celebration |
| Capture | One text field. Which Path, quest or practice, when could you do this (cue chips). Three taps to save. | Plus button anywhere | Back to caller |
| Celebration | Full-screen moment when a milestone is ticked. Glyph animates, identity label, the milestone sentence. One button. | Ticking a milestone | Path detail |
| Settings | Notification permission, quiet hours, morning and evening window times, role defaults, JSON export (phase 2). | Gear on Paths | Back |

## Onboarding flow

```mermaid
flowchart TD
  Launch[First launch] --> Ask["Name one thing you want to evolve"]
  Ask --> Template{"Start from a template?"}
  Template -->|Restore or fix| Fill[Prefilled Path, editable]
  Template -->|Learn piece by piece| Fill
  Template -->|Decision with a deadline| Fill
  Template -->|Machine or project to tinker on| Fill
  Template -->|Blank| Empty[Empty Path]
  Fill --> Identity["Who are you on this Path? (identity label)"]
  Empty --> Identity
  Identity --> Quests["Write 3 quests, each with a cue"]
  Quests --> Milestone["Write 1 milestone as a sentence"]
  Milestone --> Notify["Allow notifications so objectives can find you"]
  Notify --> Today[Today screen with first objective or a 'tomorrow' note]
```

## Daily flow

```mermaid
flowchart LR
  Open[App opens or daily refresh] --> Engine["Engine.plan(nextDays: 7)"]
  Engine --> Schedule["Schedule UNCalendarNotificationTrigger per day"]
  Schedule --> Wait[Phone, nothing running]
  Wait --> Fire["Notification: New objective"]
  Fire -->|Done| Log[LogEntry written, node done]
  Fire -->|Not now| Skip["skipCount += 1, resurface after 7 days"]
  Fire -->|Too big| Split["Open Capture prefilled to split the node"]
  Fire -->|Tap| Today[Today screen]
  Log --> MilestoneQ{"User ticks a milestone?"}
  MilestoneQ -->|yes| Celebrate[Celebration]
  MilestoneQ -->|no| Today
```

## Capture flow

```mermaid
flowchart LR
  Plus[Plus button] --> Text["Text field: what is it"]
  Text --> Which["Path chip row (last used preselected)"]
  Which --> Kind["Quest or Practice (segmented)"]
  Kind --> When["When could you do this? chips: weekend, weekday, morning, evening, anytime, a date"]
  When --> Save[Save]
```

## Path lifecycle

```mermaid
stateDiagram-v2
  [*] --> Active
  Active --> Paused: user pauses
  Paused --> Active: user resumes
  Active --> Evolved: all milestones ticked
  Evolved --> Active: user adds a milestone
  Active --> Archived: user archives
  Archived --> Active: user restores
```

## Node lifecycle

```mermaid
stateDiagram-v2
  [*] --> Todo
  Todo --> Surfaced: engine picks it
  Surfaced --> Done: Done action (quest)
  Surfaced --> Todo: Done action (practice, lastDone updated)
  Surfaced --> Todo: Not now, skipCount 1
  Todo --> Paused: second Not now in a row
  Paused --> Todo: user reopens
  Todo --> Stale: 30 days untouched
  Stale --> Todo: user says still want it
  Stale --> NotTaken: silence
  Done --> [*]
  NotTaken --> [*]
```

## Notification anatomy

Title: the Path identity, e.g. "Guitarist". Body: "New objective: change the strings". Category `objective` with three actions. `done` (foreground optional), `later` (background), `toobig` (foreground). Thread identifier is the Path id so one Path's objectives stack.
