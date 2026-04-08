# Evil Master Plan

Evil Master Plan is a SwiftUI multiplatform planning app for macOS, iPadOS, and iPhone. It is built for parallel project work: many active threads, fast capture, visible blockers, and a short path from rough idea to concrete action.

## Platforms and Stack

- macOS
- iPadOS
- iPhone
- Swift
- SwiftUI
- SwiftData
- no third-party dependencies

## Current State

The repository now contains a working Phase 6 planning flow:

- one shared planning model for projects, steps, inbox items, dependencies, and visualization preferences
- SwiftData-backed local persistence with shared bootstrap and preview data
- an adaptive app shell for macOS, iPadOS, and iPhone
- an Inbox that supports quick capture, review, conversion, archiving, permanent deletion, and retained conversion history
- a Focus cockpit that surfaces blocked work, next steps, urgent milestones, and inbox triage from the same stored data
- Projects, Bubble Network, Gantt, and Dependencies all reading the same project, step, and dependency entities
- centralized mutation workflows for rescheduling, reprioritization, step reordering, archive, restore, and safe delete side effects
- archive-aware filtering so active planning surfaces hide archived projects by default and can reveal them explicitly
- seed data and tests that exercise inbox lifecycle states, conversion flows, blocker logic, focus derivation, archive filtering, and destructive cleanup rules

The app is no longer only a visualization surface. It now supports the full loop from capture to structured work to focused execution and day-to-day editing.

## Architecture

The app uses one central domain model, one central mutation layer, and multiple shared projection layers:

- Persistent core models: `Project`, `ProjectStep`, `Dependency`, `IdeaInboxItem`, `VisualizationPreferences`
- Shared mutation workflow: `PlanningMutationWorkflow`
- Shared planning mapping: `PlanningResolver`, `PlanningTimelineEntry`, `PlanningDependencyEdge`, `PlanningTimelineSnapshot`
- Shared inbox workflow: `InboxSectionSnapshot`, `InboxSnapshot`, `InboxWorkflow`, `InboxConversionRequest`, `InboxConversionResult`
- Shared focus projection: `FocusCandidate`, `FocusSectionSnapshot`, `FocusSnapshot`
- Bubble-specific visualization types: `BubbleGraph`, `BubbleNode`, `BubbleEdge`, `BubbleInspectorContext`
- SwiftUI feature screens reading the same stored models and rendering different working surfaces

This is the core architectural decision: Inbox, Focus, Projects, Bubble, Gantt, and Dependencies do not own separate data worlds, conflicting blocker logic, or their own delete semantics.

### Why SwiftData

SwiftData is used because the app needs:

- local-first persistence with minimal glue code
- direct integration into SwiftUI and previews
- a path toward CloudKit/iCloud sync later

The persistence setup is centralized in [PersistenceController.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/PersistenceController.swift), so storage concerns stay out of feature views.

## Folder Structure

- [App](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/App): app entry, destinations, shell, navigation state
- [Domain](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain): persistent entities, enums, shared projections, planning timeline logic
- [Data](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data): `ModelContainer`, bootstrap, sample content
- [Features/Dashboard](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dashboard): Focus cockpit
- [Features/Projects](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Projects)
- [Features/Inbox](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Inbox)
- [Features/BubbleNetwork](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork)
- [Features/Gantt](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Gantt)
- [Features/Dependencies](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dependencies)
- [Features/Settings](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Settings)
- [DesignSystem](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/DesignSystem): shared cards, badges, focus cards, quick actions, theme
- [Shared](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Shared): cross-feature SwiftUI helpers
- [PreviewSupport](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/PreviewSupport): in-memory preview container

## Data Model Overview

### `Project`

- title, summary, status, priority, progress
- created and updated timestamps
- optional start and due dates
- optional `archivedAt` timestamp for archive state
- tags and a visual color token
- relationship to ordered `ProjectStep` records

### `ProjectStep`

- belongs to a project
- carries status, priority, progress, notes, ordering, and optional dates
- supports both tasks and milestones through `ProjectStepKind`
- remains a first-class editable unit for status, priority, progress, dates, ordering, and deletion
- works as the shared actionable unit for Projects, Focus, Bubble, Gantt, and Dependencies

Milestones are intentionally not a second task system. They stay embedded in `ProjectStep`.

### `Dependency`

- stores `sourceKind + sourceItemID`
- stores `targetKind + targetItemID`
- stores dependency type and note
- is directly deletable when a plan needs to be restructured

SwiftData does not offer a strong polymorphic relationship story for “project or step”, so the dependency model uses stable identifiers plus type metadata.

### `IdeaInboxItem`

- title and body for fast capture
- `createdAt` and `updatedAt`
- lifecycle state through `IdeaInboxState`
- optional tags, source, and priority hint
- optional `convertedAt`, `archivedAt`, and conversion target metadata
- optional links to the created `Project` and `ProjectStep`
- converted links can be cleared again if the linked planning target is later deleted

`IdeaInboxState` is now a real lifecycle:

- `open`: newly captured and not yet reviewed
- `reviewing`: actively triaged, enriched, or awaiting a decision
- `converted`: preserved source item that already produced a project, step, or milestone
- `archived`: explicitly discarded or parked

### `VisualizationPreferences`

- bubble sizing criterion
- bubble grouping mode
- shared timeline scale (`week` / `month`)
- default project sort
- completed-item visibility
- high-priority-only filtering
- singleton-style app scope via a unique `scope` key

## Inbox Workflow

The Inbox is now a real triage stage instead of a dead-end capture bin.

### Capture

- Quick capture writes an `IdeaInboxItem` in state `open`
- capture remains intentionally light: title first, optional body, structure later

### Triage

- the queue is grouped by lifecycle state
- filters support `Needs Triage`, `Reviewing`, `Converted`, `Archived`, and `All`
- detail editing supports title, body, tags, source, and priority hint before conversion
- triage decisions are explicit: review, reopen, archive, convert, open the generated target, or permanently delete the item

### Conversion

Conversion is handled centrally by [PlanningProjections.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain/PlanningProjections.swift), not scattered through view code.

Supported flows:

- Inbox item -> new project
- Inbox item -> new task in an existing project
- Inbox item -> new milestone in an existing project

Conversion behavior:

- the original inbox item is retained
- the inbox item moves to `converted`
- conversion timestamps and target type are stored
- links to the created project and optional step are stored
- title, notes, tags, and priority hints are carried forward into the created planning object
- if the linked project or step is later deleted, the inbox item is reopened for review instead of keeping a broken zombie link

This keeps conversion reversible at the workflow level because the source context does not disappear.

## Focus Cockpit

The start screen is now a Focus cockpit, not a greeting board.

The Focus view is derived centrally by [PlanningProjections.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain/PlanningProjections.swift) through `FocusProjectionFactory`.

It currently produces five sections:

- `Now Important`
- `Blocked`
- `Next Sensible Steps`
- `Inbox Review`
- `Milestones Soon`

Focus scoring is rule-based and intentionally transparent:

- project and step status
- project and step priority
- due-date urgency
- recent updates
- open-step density
- unresolved predecessors and blocker state via `PlanningResolver`

The Focus cockpit does not invent a second planning model. It curates relevance from the same entities already used by Projects, Bubble, Gantt, and Dependencies.

### Focus Navigation

- focus cards deep-link into Projects, a concrete Step, or an Inbox item
- Projects can scroll directly to the focused step when opened from Focus
- Inbox items selected from Focus land in the triage detail panel instead of a dead list view

## Bubble, Gantt, and Dependency Consistency

Phase 6 keeps the planning surfaces consistent while also making them actionable.

- Bubble, Gantt, Dependencies, Focus, and Projects all read the same `Project`, `ProjectStep`, and `Dependency` records
- blocker evaluation comes from `PlanningResolver`
- milestone handling stays embedded in `ProjectStepKind`
- status and priority semantics come from shared enums, not per-screen heuristics
- schedule changes, priority changes, archive state, and delete cleanup all flow through shared mutation rules
- an inbox conversion creates normal projects or steps, so the converted result appears naturally in Bubble, Gantt, and dependency views

This means Focus complements the existing planning surfaces instead of disagreeing with them.

## Editing Workflows and Mutation Safety

Phase 6 introduced a deliberate distinction between archive and delete instead of treating both as generic persistence actions.

### Central Mutation Layer

- [PlanningMutations.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain/PlanningMutations.swift) centralizes destructive and restructuring workflows
- project deletion removes the project, its steps, all related dependencies, and reopens linked inbox conversions for review
- step deletion removes incoming and outgoing dependencies, normalizes step ordering, and reopens linked inbox conversions for review
- dependency deletion touches affected projects so every projection sees the updated structure
- schedule helpers support start today, shift by days, and clear dates for both projects and steps
- priority helpers support quick raise and lower actions without scattering rank logic through views

### Archive vs Delete Strategy

- Projects: archive is the default safe action; permanent deletion is secondary and always requires confirmation
- Steps and milestones: direct delete is allowed, but it goes through cleanup logic for dependencies and linked inbox references
- Inbox items: archive keeps history, permanent delete removes the item completely
- Dependencies: direct delete is allowed because they are structural links, not long-lived work objects

Archived projects are hidden from active planning surfaces by default. They can be restored from Projects and shown explicitly in Bubble, Gantt, and Dependencies when the user opts in.

### Quick Actions and Edit Surfaces

- Projects view: full editor for title, summary, status, priority, progress, dates, tags, archive, restore, permanent delete, add step, add milestone, and step reordering
- Dashboard / Focus: context menus for status changes, priority nudging, rescheduling, archive or restore, and safe delete from the focus candidate itself
- Bubble inspector: quick status, priority, schedule, archive or restore, open-in-projects, and delete actions from the currently selected node
- Gantt inspector: quick status, priority, schedule, dependency removal, archive or restore, open-in-projects, and delete actions from the selected entry
- Dependencies inspector: the same planning actions as Gantt, plus direct removal of dependency edges
- Inbox queue and detail: review, reopen, archive, convert, open target, and permanent delete

The app still avoids fake inline editing where domain safety would become unclear. It prefers compact action menus and inspector actions backed by shared logic.

## What Works Right Now

- `WindowGroup` app shell with adaptive navigation for macOS, iPadOS, and iPhone
- Focus cockpit with real actionable sections and deep links
- Project list with active, archived, and all scopes plus an editable detail panel
- project steps and milestones edited as one unified structure, including reordering, reprioritization, rescheduling, and safe deletion
- Inbox quick capture with queue, filters, lifecycle badges, detail editing, conversion actions, archive, and permanent delete
- conversion from Inbox into new projects, project tasks, and project milestones
- retained conversion history on the original inbox item
- Bubble view driven by real projects, focused steps, milestones, and stored dependencies, with inspector quick actions
- Gantt view driven by shared planning timeline entries, including derived schedules for partially planned work and inspector quick actions
- dependency timeline driven by the same planning entries and real dependency edges, with blocker highlighting, dependency removal, and inspector quick actions
- archive-aware filtering across Projects, Bubble, Gantt, Dependencies, and Focus
- safe delete confirmation flows for destructive project, step, and inbox actions
- settings persisted through `VisualizationPreferences`
- shared seed/bootstrap data for first launch and previews

## Bubble Network

The Bubble Network is a real working surface instead of a decorative graph.

- Data sources: `Project`, focused `ProjectStep` and milestone subsets, and stored `Dependency` records.
- Mapping layer: [BubbleGraphMapper.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork/BubbleGraphMapper.swift) translates domain entities into visualization nodes, edges, inspector context, and summary metrics.
- Layout layer: [BubbleGraphLayout.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork/BubbleGraphLayout.swift) groups projects deterministically by status or priority and places focused steps around the focused project.
- Presentation layer: [BubbleNetworkView.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork/BubbleNetworkView.swift), [BubbleGraphCanvasView.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork/BubbleGraphCanvasView.swift), and [BubbleInspectorView.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork/BubbleInspectorView.swift).

### Current Bubble Interactions

- select a bubble to inspect status, priority, progress, open steps, milestones, and dependency context
- focus a project to expand a controlled set of relevant steps and milestones without exploding the graph
- switch bubble sizing between `priority`, `progress`, `dependencyCount`, and `openStepCount`
- group the graph by `status` or `priority`
- filter to all, active, or blocked projects and optionally hide completed, limit the map to high-priority projects, or reveal archived projects
- use inspector quick actions to change status, change priority, move schedules, archive or restore a project, open it in Projects, or permanently delete the selected object

## Shared Planning Timeline

Phase 4 introduced a single planning timeline layer for Gantt and Dependencies, and Phase 6 keeps using it as the shared planning spine for read and write workflows.

- planable unit: `ProjectStep`
- milestone strategy: milestones stay embedded in `ProjectStep`
- container/grouping unit: `Project`
- dependency model: stored `Dependency` records can target `Project` or `ProjectStep`

### Planning Mapping Layer

- [PlanningTimeline.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain/PlanningTimeline.swift) builds `PlanningTimelineSnapshot` from stored domain entities
- `PlanningResolver` centralizes title, status, progress, dependency counts, predecessor lookup, and blocker evaluation
- `PlanningTimelineBuilder` centralizes schedule fallback logic, derived schedule shifting, dependency edge resolution, and project grouping

### Schedule Handling

- explicit dates are respected when present
- milestones remain single-day markers
- if steps have missing dates, the timeline derives dates from the project container or a stable sequence fallback
- derived schedules are visibly marked in the UI instead of pretending to be fully planned
- quick rescheduling actions update the same stored dates that Bubble, Focus, Gantt, and Dependencies later read

### Blocker Logic

- `finishToStart` and `finishToFinish` links block while the source item is not done
- `startToStart` links block while the source item has not started
- project rows aggregate their own incoming blockers plus blocked and incomplete child steps
- Bubble Network and Focus use the same dependency-driven blocker logic as Gantt and Dependencies
- removing a step, project, or dependency clears affected blocker links instead of leaving stale references behind

## CloudKit / iCloud Preparation

The code is prepared for CloudKit-capable SwiftData configuration, but sync is intentionally not active by default.

Before enabling it, verify these items in Xcode for the app target:

1. `Signing & Capabilities` still uses the intended automatic signing team.
2. Add the `iCloud` capability.
3. Enable `CloudKit`.
4. Create or select the correct default container.
5. Only then opt the app into `.automatic` CloudKit database usage in [PersistenceController.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/PersistenceController.swift).

The repo currently avoids forcing entitlement changes from code because that would be risky in a fresh project.

## Testing

The current tests cover:

- sample data integrity and lifecycle coverage for inbox states
- inbox conversion into projects and existing project steps
- reopening converted inbox items when linked projects or steps are deleted
- focus projection for blocked work, milestones, and triage items
- bubble graph sizing, focus expansion, and deterministic layout
- planning timeline generation for Gantt and Dependencies
- milestone-as-step handling
- blocker detection and blocked-only filtering
- archive filtering in shared planning projections
- bootstrap seeding behavior for in-memory SwiftData stores
- singleton preference seeding
- basic model invariant enforcement for project and step date, progress, and status normalization

## Prepared but Not Finished

- dedicated “attach inbox item as project note” flow
- snooze or scheduled re-review semantics for inbox items
- user-tunable focus weights, saved focus views, or explicit “today plan” commits
- richer dependency creation and chain authoring
- direct drag-editing of schedules and links in Gantt or Dependencies
- archive-specific restore views beyond the current project scopes and show-archived toggles
- saved bubble layouts, zoom and pan persistence, and manual positioning
- CloudKit sync activation and merge behavior testing

## Known Limits

- common restructuring and destructive flows are centralized, but not every field edit is yet routed through a dedicated domain service
- dependency creation UI is still minimal compared with the read-side visualizations
- focus scoring is deterministic and explainable, but not yet user-configurable
- conversion keeps source context, but it does not yet record a richer audit trail beyond timestamps and target links
- the current Gantt and dependency layouts are useful planning tools, but not the final interaction model
- archived steps are modeled through their parent project context; there is no separate step archive state yet

## Next 3 Sensible Steps

1. Add first-class dependency authoring and editing so links can be created, retargeted, and explained with the same safety guarantees as current deletion flows.
2. Extend Inbox and archive workflows with restore queues, snooze or revisit dates, and richer post-conversion history instead of only state badges and target links.
3. Introduce more direct schedule manipulation in Gantt and Dependencies, then validate conflict handling, undo strategy, and eventual CloudKit merge behavior.
