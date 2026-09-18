# Pixel World redesign proposal

Status: irregular local quest clusters, build 40, 2026-09-18. Original research and proposal follow the implementation notes below.

## Implementation notes

WorldLayout retains four outward regions for safe routing, but no longer places work on a shared outer ring. Each path's quests and routines fill compact staggered clusters, with short local connections and stable ID-derived variations in room depth, transverse spacing, branch direction, and path offset. Crowded paths fill two dimensions instead of forming one long row. All real routes remain orthogonal and outward-only. Path rooms stay independent of quest population. Rooms are 136×72 points; the first work room of each of four paths stays within 300 points of its parent even when a different path has 50 quests (regression tested). Large worlds still require pan/zoom or the menus.

Unused space now contains a deterministic decorative maze forest, capped at 8,000 grid cells and buffered away from real rooms/corridors. Its dim vector strokes are noninteractive and have no quest data. Geometry is regenerated only when structure changes; a 1,000-quest decoration benchmark takes about 107 ms locally for the more detailed build-40 corridors.

The layout and corridor geometry are cached by path/work IDs. Native UIScrollView handles pan/zoom without SwiftUI gesture-state updates. CAShapeLayer draws the corridors as vectors instead of a world-sized Canvas bitmap. Selection is immediate with no queued Task or delayed travel animation. Real SwiftUI buttons expose room labels and actions; Paths and Quests menus provide access when overview targets are too small. Open edits the selected quest or opens its path. Recenter and overview are explicit controls. Reduce Motion disables camera animation.

Tests cover outward segments, axis alignment, room clearance, branches crossing other paths, deterministic output, empty and uneven populations, and a 1,000-quest placement benchmark (about 30 ms locally in a debug Linux test; not a device rendering benchmark). On-device frame rate, VoiceOver navigation during zoom, and large Dynamic Type still need hands-on verification. Fixed-size map labels may truncate; the selection panel and menus show the full names. Structural edits may rearrange lanes; ordinary selection/panning does not recalculate the layout.

## Goal

You at the center; paths in the next layer; each path's quests and routines farther outward. Use the approved Today pixel palette and stepped panels. Branches must grow away from You, never orbit their parent or double back toward the center. Scope: Paths > World only.

## Current implementation

AtlasView.swift draws curved Canvas connections beneath SwiftUI buttons. AtlasLayout places paths on a screen-sized circle and work nodes on a fixed 62-point fan around each path. The fan spans 1.15π (207 degrees), which permits inward branches. Fixed distances do not account for labels, touch targets, or node counts. Work buttons are only 16 points across. Keep the existing data models and List alternative.

## Recommended layout

Use a custom deterministic, layered radial tree with grid-aligned orthogonal routing. Radial placement defines ownership and outward direction; horizontal/vertical corridors provide the maze appearance. This is a visual navigation map, not a generated puzzle with random walls or misleading dead ends.

1. Build a pure layout input from stable path/node IDs, measured label bounds, and open work nodes. Include routines with their distinct pixel mark; completed items remain accessible through history/path details.
2. Assign each path a nonoverlapping angular sector. Allocate space based on its visible work count and label bounds, with minimum space for empty paths. Preserve stored path order and avoid reshuffling on selection/completion. Recompute when structure or available text size changes; preserve the focused node's camera position.
3. Place path rooms in an inner band and work rooms in a strictly outer band within their parent's sector. Use a minimum outward projection and full bounding-box clearance, not merely greater center distance. One child goes straight outward; several spread into an outward fan. Many children enlarge the world and outer radius, rather than wrap around their parent or acquire a false dependency hierarchy.
4. Snap positions and corridor bends to a coarse logical grid. Use obstacle-aware orthogonal routes through reserved corridors, joining node boundaries at explicit ports. Routes from You may share trunks until they split. Routes from separate paths must not cross or run through any room, label, or touch target.
5. Enforce outward travel on every route segment relative to You, not just endpoints. Reject any segment whose radial distance decreases; test segment interiors as well as vertices. Routing and placement must be solved together: if a valid route cannot fit, expand/reposition within the sector and retry. Do not silently fall back to an inward or crossing route. Prototype this constraint early, especially sectors near quadrant boundaries.
6. Reserve node/label clearance before drawing. Use larger world coordinates independent of the viewport. Fit the overview, allow pan/pinch, and provide a visible recenter control. At overview scale, simplify quest labels and expose counts; selecting a path focuses its sector with readable labels and usable controls. Show all work via this focus mode and existing List, without silently dropping overflow.

## Appearance and interaction

- Center: small pixel brain/You room. Paths: larger stepped rooms with name and glyph. Quests/routines: smaller stepped rooms with distinct pixel symbols.
- Burgundy ground, cream text, brass selection and corridors; darker Work rooms. No animated particle sky or soft circular orbs.
- Tap a room to select and highlight its route. Tap again to deselect, matching Today. A compact selection panel offers an explicit Open action; quest selection opens the corresponding quest editor rather than only its parent path. Keep names available to VoiceOver.
- Canvas draws only corridors and decorative grid details. Overlay real SwiftUI controls for nodes and the selection panel. Maintain usable screen-space touch targets at interactive zoom; zoomed-out dense nodes should focus the sector before presenting individual actions.
- Respect Reduce Motion; no mandatory travel animation. Keep Today and Paths > List unchanged.

## Delivery sequence

1. Prototype the pure layout and routing with fixture data, before replacing AtlasView. Review a static preview with 4–6 paths, including empty, single-quest, and crowded paths.
2. Validate the outward-only invariant, sector separation, no crossing/overlap, deterministic output, and node completeness. Include zero/one/many paths, uneven populations (1 vs 20), long names, and large text.
3. Replace World rendering with native stepped rooms and orthogonal corridors, reusing PixelPanel. Add selection, focus, pan/zoom, recenter, and real node actions.
4. On-device checks: small iPhone, landscape/layout changes where supported, Dynamic Type, VoiceOver, Reduce Motion, completion while focused, rapid additions/removals, and 100+ nodes. Check that selection does not move rooms and that zooming does not strand the camera.

No third-party layout runtime is recommended initially: this app has a shallow two-level ownership tree and specific outward-only constraints. If prototype routing becomes disproportionately complex, reassess an established layout engine rather than accumulating ad hoc fixes. Ordinary radial layout alone does not guarantee the requested corridor behavior.

## Research

- yWorks radial layout: children occupy an outer layer inside sectors reserved by parents. Supports the core layout choice, not the custom orthogonal/outward-only guarantee: https://docs.yworks.com/yfiles-html/dguide/layout/radial_layout.html
- yWorks radial tree: subtree sector allocation and spacing to avoid overlap: https://docs.yworks.com/yfiles-html/api/RadialTreeLayout/
- Eclipse ELK radial algorithm, an alternative layout reference: https://eclipse.dev/elk/reference/algorithms/org-eclipse-elk-radial.html
- Apple Canvas: individual drawn elements have no built-in interaction/accessibility; retain real controls above the drawing: https://developer.apple.com/documentation/swiftui/canvas

The proposed grid routing, interaction design, and implementation sequence are project-specific recommendations, not guarantees supplied by these libraries.

## Build 42: one discoverable maze

WorldMaze replaces the separate decorative forest and visible ownership roads.
Room positions remain compact and irregular. The ownership backbone is bent into
clear U-shaped detours, then a seeded spanning tree grafts the surrounding maze
onto it. All unselected roads share the same native vector style. There is one
route to each destination; a child's journey goes through its own path. Unused
branches are connected possibilities, not a disconnected background drawing.

Selecting a path reveals its route and children's routes. Selecting a child
reveals only its journey from You. Tapping the maze or the selected room clears
it. Room taps preserve the camera so the route remains visible; the Paths/Quests
menus still focus distant rooms. Open continues to navigate/edit the selection.

Geometry runs in a cancellable detached task and is cached until room IDs change.
Metadata edits reuse it, and selections only change the highlighted vector path.
The background grid adapts to world size; collinear roads are collapsed before
rendering. Engine tests cover ancestry, continuity, a connected acyclic network,
detours, deterministic regeneration, open-space density and 1,000-item worlds.

## Build 43: walls enclose walkable floors

Build 42 drew a road graph, which still made its lines read as connections.
WorldMaze now models cells, chambers and doorways. Adjacent cells keep a wall
unless a doorway is carved between them. Rooms have wall-free interiors and real
openings; their labels no longer have a closed decorative outline.

The compact ownership layout guides winding walks from You to paths and from
paths to their children. These journeys are carved first. The remaining doors
form a spanning tree, so there is exactly one route between chambers/cells.
Selection fills a 12-point strip down the middle of 16-point passages. Two-point
walls use separate geometry and render above the floor; the highlight never
replaces a wall. Room positions snap by at most eight points to the maze grid.

Generation remains cancellable and off the UI thread. Large worlds use coarser
background chambers away from rooms and reserved journey areas, while keeping
those areas detailed. The 1,000-item fixture generates about 67,000 merged wall
segments instead of 234,000. Metadata edits and selection reuse the cached maze.

Tests verify wall/door agreement, connected acyclic passage topology, highlight
clearance, parent gateways across varied families, determinism, room separation,
non-direct journeys, and the 1,000-item case. A rendered geometry preview was
reviewed locally; that preview is not an iOS interaction test.

## Build 44: even spacing, doorway stops, outward light

Room placement uses a regular 176-point pitch instead of per-room jitter and
mixed horizontal/vertical spacing. The four inner paths have equal distance from
You. Larger families retain clearance for their outward branches. Symmetric,
maze-aligned bounds keep You at the exact center, even with uneven family sizes.

An even-odd floor mask excludes every chamber interior. Selected passages reach
the doorway, disappear through the room, and continue from the exit doorway;
the labels and room interiors never receive the route highlight.

WorldReveal builds a prefix tree of the selected journeys. Shared passages light
once, then child branches start when the light reaches their junction. Cached
native layer animations reveal the route in 2.5–6 seconds without per-frame
SwiftUI state. Deselecting or changing destinations removes previous animations;
metadata changes do not replay them. Reduce Motion shows the full route directly.

Tests cover shared-prefix timing, duplicate-route suppression, preserved corners,
centered bounds after maze snapping, and equal inner-path spacing, alongside the
existing maze clearance, ancestry and large-world checks.

## Build 45: nested mazes

The main World scene projects only non-archived paths around You. An inner scene
projects only its parent's open quests/routines around that path. The same wall,
doorway, spacing and reveal systems serve both levels; domain IDs and saved data
are unchanged. Child edits do not invalidate outer geometry. Scenes build only
when visited and cache their geometry while on the navigation stack.

First tap selects and enlarges the room's icon/title by 20% within its chamber,
without moving walls or blocking doors. Second tap enters a path or opens a
quest/routine editor. The selection panel supplies explicit Enter/Open actions;
Details still opens the normal path screen. Tapping empty maze space deselects.
The inner center opens path details, and its plus button adds directly to that
path. Empty paths have an Add action; archived/deleted parents dismiss the maze.

Native Back/swipe-back returns to the outer scene. Selection, zoom and pan are
kept per level in non-publishing viewport storage. Restored positions are clamped
to the new viewport bounds; showing a selection panel no longer refits the map.

Engine coverage verifies level isolation, resting/archive handling, open-node
filtering, centered inner layouts, and unchanged outer inputs after child edits.
Phone review should exercise select/second-tap entry, Back after pan/zoom, editing
or completing a child, empty paths, and archiving a parent from its Details screen.
