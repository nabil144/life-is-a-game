# Pixel World redesign proposal

Status: first implementation, build 37, 2026-09-18. Original research and proposal follow the implementation notes below.

## Implementation notes

WorldLayout now uses four cardinal regions and disjoint lanes, a constrained version of the proposed radial sectors. This makes monotone orthogonal routing deterministic without a general obstacle-routing solver. Rooms are 136×72; transverse lanes reserve 160 points and grow with quest count. Large worlds need pan/zoom or the Paths menu; fitting every title legibly on one phone screen is not possible.

The layout and corridor geometry are cached by path/work IDs. Native UIScrollView handles pan/zoom without SwiftUI gesture-state updates. CAShapeLayer draws the corridors as vectors instead of a world-sized Canvas bitmap. Selection is immediate with no queued Task or delayed travel animation. Real SwiftUI buttons expose room labels and actions; Paths and Quests menus provide access when overview targets are too small. Open edits the selected quest or opens its path. Recenter and overview are explicit controls. Reduce Motion disables camera animation.

Tests cover outward segments, axis alignment, room clearance, branches crossing other paths, deterministic output, empty and uneven populations, and a 1,000-quest placement benchmark (about 2 ms locally in a debug Linux test; not a device rendering benchmark). On-device frame rate, VoiceOver navigation during zoom, and large Dynamic Type still need hands-on verification. Fixed-size map labels may truncate; the selection panel and menus show the full names. Structural edits may rearrange lanes; ordinary selection/panning does not recalculate the layout.

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
