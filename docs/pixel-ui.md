# Pixel UI

Build 41 extends the refined Today visual language to Paths, path details,
creation and editing, settings, help, chat, completion, onboarding and backup.

## Shared components

- `PixelPanel`: native stepped corners; qualify drawing paths as `SwiftUI.Path`
  because the app has a global `Path` alias for its domain model.
- `PixelList`: plain native list with compact stepped row backgrounds, six-point
  visible gaps, hidden separators and scroll indicators. Supports native swipe,
  reorder, navigation and input controls. Use this for editor/settings screens.
- `pixelCard()`: matching panel and border for standalone content and chat drafts.
- `PixelButtonStyle`: compact option has a 30-point visible panel and at least a
  44-point touch target. Selected options use brass; disabled controls fade and
  destructive controls retain a red label.
- `PixelChoices`: small sets of choices; selected state is exposed to VoiceOver.
  Falls back to a vertical layout when the horizontal choices do not fit.
- `PixelQuestMark`: shared quest/routine sprite. Keep custom path glyphs readable.

Use monospaced type for short navigation labels, buttons and selected headings.
Keep body text, descriptions, notes, editable fields and longer titles in normal
system type. Date pickers, menus, toggles, system sheets and tab navigation retain
native behavior. Do not apply a global pixel button style to list rows or inputs.

Today keeps its pinned two-line date/time header, compact controls, individual
row highlights and uniform row spacing. World keeps its cached layout and native
scroll/zoom rendering. Avoid animated decoration or per-frame layout rebuilding.

## Visual review on a phone

Review Paths in List and World mode, path details and history; create/edit both a
quest and routine; test the larger accessibility text sizes with cue choices;
open Settings, Help, Model setup and the completion/photo sheet; review chat
bubbles and its composer with the keyboard visible. Also check milestone editing,
celebration and the backup prompt. Automated startup checks do not cover these
interactions or verify every screen visually.
