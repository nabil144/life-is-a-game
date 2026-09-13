# Copy deck

Every string the user sees. Quest-log voice. Short. No exclamation marks. Never the words reminder, task, to-do, streak, level, points.

## App

- Name (working): Life is a Game
- Tab: Today
- Tab: Paths

## Notifications

- Title: `{identity}` (e.g. Guitarist)
- Body: `New objective: {node title}`
- Action: Done
- Action: Not now
- Action: Too big
- Stale check body: `Still want this? {node title}`
- Stale check actions: Keep it · Let it go
- Decision, final days: `{days} days left to decide: {path name}`

## Today

- Header: Today
- Subheader: `{weekday}, {day} {month}`
- Card eyebrow: New objective
- Card meta: `{identity} · {cue} · after "{blocker}"` (parts omitted when absent)
- After the card: That is all for today. One thing, done well.
- No objective, quiet day: Nothing is due today. Your paths are resting.
- No objective, all evolved: Every path has evolved. Add a milestone or start a new path.
- No objective, no notification permission: Objectives cannot find you yet. Allow notifications in Settings.
- Recently section: Recently
- This week section: This week

## Paths

- Header: Paths
- Row meta, active: `{identity} · next: {next milestone}`
- Row meta, decision: `Deciding · {days} days left`
- Row meta, evolved: Evolved
- Row meta, paused: Resting
- Empty: Name one thing you want to evolve.
- Add button: New path
- View segment: World · List
- World hint, far: Pinch closer. Drag to wander.
- World hint, close: The smaller rings are milestones. Tap a path to open it.
- World self: You

## Path detail

- Subheader: `{identity} · {role} · surfaces {role window text}`
- Role window text: hobby = evenings and weekends; craft = evenings and weekends; lab = weekends; decision = once a week until the deadline; work = weekday mornings
- Milestones section: Milestones
- Milestone hint, untick: tap when true
- Milestone hint, ticked: `true on {date} · tap to change`
- Milestone add row: Add a milestone as a sentence
- Quests section: Quests
- Practices section: Practices
- Log section: Log
- Node meta, quest: `{cue} · after {blocker}`
- Node meta, practice: `{cue} · last {relative day}`
- Node badge, surfaced today: today
- Node state, paused: paused, tap to reopen
- Node state, not taken: path not taken
- Quests footer: Tap one to change it. Swipe to let it go. Plus adds another.
- Node swipe: Let it go
- Pause path: Let it rest
- Resume path: Continue
- Archive path: Put it away
- Evolved banner: This path has evolved. It will stay here, quiet.
- Header hint: Tap to change this path.

## The fact (ticked milestone)

- Header: The fact
- Date: It became true on
- Footer: A tap on the path should not take this back. Change the day if the app was not here yet.
- Keep: Keep it
- Take back: It was not true yet
- Take back confirm: Take the tick back?
- Take back message: The path will no longer show this as true.
- Edit: Edit

## This path (edit)

- Header: This path
- Name placeholder: What are you evolving?
- Identity placeholder: Who are you on this path? e.g. Guitarist
- Role label: What kind of path is this?
- Deadline label (decision only): Decide by
- Glyph label: Glyph
- Milestones header: Milestones
- Milestone placeholder: A sentence that will be true, e.g. It holds tune
- Add milestone: Add another milestone
- Milestones footer: Tap a milestone on the path to tick it. Here you change the words, the order, or drop one.
- Save: Save
- Cancel: Cancel

## Capture

- Header: Capture
- Text field placeholder: What is it?
- Path picker label: On which path
- Kind segmented: Quest · Practice
- Kind helper, quest: Something you do once.
- Kind helper, practice: Something you return to.
- Cue label: When could you do this?
- Cue chips: Weekend · Weekday · Morning · Evening · Anytime · Pick a date
- Blocker label: Only after (optional)
- Save: Add to path
- Too big prefill title: `Part of: {original title}`
- Too big hint: Write the first small piece.

## New path

- Header: New path
- Section header: Name it, then one milestone
- Name placeholder: What are you evolving?
- Milestone placeholder: A sentence that will be true, e.g. It holds tune
- Add milestone: Add another milestone
- Template menu: Start from an example
- Templates: Something to restore or fix · A skill to learn piece by piece · A decision with a deadline · A machine or project to tinker on
- Template note: Examples are yours to edit or delete.
- More row: More
- Identity placeholder: Who are you on this path? e.g. Guitarist
- Role label: What kind of path is this?
- Role options: A hobby · A craft · A decision · A lab · Work
- Deadline label (decision only): Decide by
- Glyph label: Glyph
- Quests header inside More: First quests
- Quest placeholder: Something small
- Add quest: Add a quest
- Add practice: Add a practice
- More footer: All of this is optional. Quests can be added from the path any time.
- Save: Begin

## Talk a path

- Header: New path
- Opening line (fixed, not from the model): What is the thing? Say it however it comes.
- Composer placeholder: Say it however it comes
- Card headers: Milestones · Quests and practices
- Trouble lines: see Talk errors under Settings
- Exit to form: Type it instead
- Save: Begin

## Edit a quest or practice

- Header: Quest · Practice
- Text field placeholder: What is it?
- Kind segmented: Quest · Practice
- Cue label: When could you do this?
- Blocker label: Only after (optional)
- Remove: Let it go
- Remove confirm: `Remove {node title}?`
- Save: Save

## Celebration

- Eyebrow: Milestone
- Line: `{milestone sentence}`
- Sub: `{identity}. {path name} is evolving.`
- Button: Continue
- Evolved variant sub: `{path name} has evolved.`

## Onboarding

- Screen 1 header: Life is a game.
- Screen 1 body: Not with points. With paths you write yourself, and one objective a day that finds you when the moment is right.
- Screen 1 button: Begin
- Screen 1 restore: I already have a copy
- Screen 2 header: Name one thing you want to evolve.
- Screen 3 header: Who are you on this path?
- Screen 4 header: Write three quests.
- Screen 4 sub: Small enough to finish in one sitting. Pick when you could do each.
- Screen 5 header: Write one milestone.
- Screen 5 sub: A sentence that will be true when this path has moved. "It holds tune." "I performed it for someone."
- Screen 6 header: Let objectives find you.
- Screen 6 sub: One notification a day at most. Never the same one twice in a week.
- Screen 6 button: Allow notifications
- Screen 6 skip: Later

## Settings

- Paths view picker: Paths screen (prototype weeks)
- Header: Settings
- Notifications row: Notifications
- Morning window: Morning objectives at
- Evening window: Evening objectives at
- Quiet days: Quiet days
- New paths section: New paths
- Key row, saved: `{provider}, {model}`
- Key row, none: Add an API key
- Talk toggle: Start new paths by talking
- Talk footer: Your own key, your own model. The model asks, you answer, it writes down your words. Either way, the New path screen offers the other.
- New path, talk row: Talk it through instead
- New path, talk row footer: Your own key, your own model. It asks, you answer, it writes down your words.
- New path, no key row: Add an API key in Settings to create paths by talking.

## Model (key setup)

- Header: Model
- Intro: Bring your own key. The app talks to the model you pay for, nothing in between. The key stays in this phone's keychain.
- Provider header: Provider
- Provider options: OpenAI · Anthropic
- Get a key link: `Get a key from {provider}`
- Key header: Key
- Key placeholder: `sk-...` · `sk-ant-...`
- Key placeholder, saved: A key is saved. Paste another to replace it.
- Model field: Model
- Test: Test · Asking the model
- Test footer: One tiny request. A fraction of a cent.
- Test verdict, ok: `{model} answered: {question}`
- Remove: Remove key
- Save: Save
- Skip (first-launch prompt only): Later

## Talk errors

- Offline: No connection. Your words are kept. Try again when you are back online.
- Bad key: The API key was not accepted. Check it in Settings.
- Rate limit: The model is busy. Wait a moment and send again.
- Refused: `The model could not answer. {reason}`
- Unreadable: Could not read the model's answer. Say it again, or press Begin with what is here.
- Data section: Your data
- Keep a copy: Keep a copy in Files
- Keep a copy, done: A copy lives in Files. New installs can pick that folder and come back.
- Forget folder: Forget the folder
- Save a copy now: Save a copy now
- Share: Share world.json
- Restore: Restore from a file
- Keep-copy sheet title: Keep a copy
- Keep-copy sheet body: The phone forgets this app when it is deleted or installed under a new name. A folder in Files does not. Pick one. iCloud Drive is safest. Every change writes there. After a new install, pick the same folder and the paths come back.
- Keep-copy sheet button: Pick a folder
- Keep-copy sheet skip: Later
- Data footer: Cmd+R keeps what is on the phone. Deleting the app, or installing it under a new name, does not. The Files copy is the one that survives.
- About: One objective a day. Progress that cannot be lost.

## Errors and edge states

- Notification denied: Objectives will only appear here in Today. You can allow notifications in iOS Settings.
- Save failed: Could not save. Try again.
- Delete path confirm: Put away `{path name}`? Its log stays.
- Delete node confirm: Remove `{node title}`?
