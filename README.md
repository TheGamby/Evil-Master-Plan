# Evil Master Plan

Evil Master Plan is a SwiftUI multiplatform planning app for macOS, iPadOS, and iPhone. It is designed for visually driven, parallel project work: many active projects, many steps, visible dependencies, and fast capture without turning into admin software.

## Platforms and Stack

- macOS
- iPadOS
- iPhone
- Swift
- SwiftUI
- SwiftData
- no third-party dependencies

## Current State

The repository now contains a hardened Phase-2 foundation:

- one shared planning model
- SwiftData-backed local persistence
- an adaptive app shell for macOS, iPadOS, and iPhone
- real baseline screens for Projects, Inbox, Bubble Network, Gantt, Dependencies, Dashboard, and Settings
- controlled seed/bootstrap data for first launch and previews
- projection logic that keeps Bubble, Gantt, and Dependencies on the same stored entities
- basic tests for model invariants, seeding, and shared projections

## Architecture

The app uses one central domain model and multiple projection layers:

- Persistent core models: `Project`, `ProjectStep`, `Dependency`, `IdeaInboxItem`, `VisualizationPreferences`
- Shared projection types: `BubbleNetworkProjection`, `GanttProjection`, `DependencyRowProjection`, `DashboardSnapshot`
- SwiftUI feature screens read the same stored models and render different representations

This is the key architectural decision: Bubble, Gantt, and Dependency views do not own separate data worlds.

### Why SwiftData

SwiftData is used because the app needs:

- local-first persistence with minimal glue code
- direct integration into SwiftUI and previews
- a path toward CloudKit/iCloud sync later

The persistence setup is centralized in [PersistenceController.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/PersistenceController.swift), so storage concerns stay out of feature views.

## Folder Structure

- [App](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/App): app entry, destinations, shell
- [Domain](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain): persistent entities, enums, shared projections
- [Data](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data): `ModelContainer`, bootstrap, sample content
- [Features/Dashboard](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dashboard)
- [Features/Projects](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Projects)
- [Features/Inbox](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Inbox)
- [Features/BubbleNetwork](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork)
- [Features/Gantt](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Gantt)
- [Features/Dependencies](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dependencies)
- [Features/Settings](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Settings)
- [DesignSystem](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/DesignSystem): panels, badges, empty states, theme
- [Shared](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Shared): cross-feature SwiftUI helpers
- [PreviewSupport](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/PreviewSupport): in-memory preview container

## Data Model Overview

### `Project`

- title, summary, status, priority, progress
- created/updated timestamps
- optional start and due dates
- tags and a visual color token
- relationship to ordered `ProjectStep` records

### `ProjectStep`

- belongs to a project
- carries status, priority, progress, notes, ordering, and optional dates
- milestone handling is intentionally embedded here via `ProjectStepKind`
- supports both Gantt rows and dependency endpoints without a second task model

This means milestones are not a second task system. They are steps with a milestone kind.

### `Dependency`

- stores `sourceKind + sourceItemID`
- stores `targetKind + targetItemID`
- stores dependency type and note

This is deliberate. SwiftData does not offer a good polymorphic relationship story for “project or step”, so the shared dependency model uses stable identifiers plus type metadata.

### `IdeaInboxItem`

- fast capture title/body
- created and updated timestamps
- conversion/archive state
- optional linked project

### `VisualizationPreferences`

- bubble sizing criterion
- default project sort
- completed-item visibility
- high-priority-only filtering
- singleton-style app scope via a unique `scope` key

## What Works Right Now

- `WindowGroup` app shell with a single adaptive `NavigationSplitView`
- dashboard snapshot built from shared project and step data
- project list with selection plus an editable detail panel
- project steps and milestones edited as one unified structure
- inbox capture, archive, and promotion into projects
- bubble view driven by real projects and real dependency counts
- Gantt projection driven by project and step dates from the same store
- dependency screen showing predecessor/successor relationships from stored `Dependency` records
- settings persisted through `VisualizationPreferences`
- in-memory previews and first-run bootstrap using the same `SeedData` source

## Intentional Phase-2 Decisions

- Milestones stay embedded in `ProjectStep` via `ProjectStepKind`. There is no parallel milestone entity.
- Bubble sizing is based only on real stored or derived data (`priority`, `progress`, `dependencyCount`). The earlier fake “effort” sizing axis was removed.
- Preferences are persisted as a single app-scoped record instead of scattered view-local toggles.
- Preview data and runtime bootstrap both use [SeedData.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/SeedData.swift), but preview container setup stays separate from production persistence.

## Prepared but Not Finished

- CloudKit sync activation and entitlement setup
- richer dependency editing and arrow-based visualization
- interactive bubble layout, selection, and graph navigation
- dedicated project/step validation flows and reordering
- more advanced focus/day-planning workflows

## CloudKit / iCloud Preparation

The code is prepared for CloudKit-capable SwiftData configuration, but sync is intentionally not active by default.

Before enabling it, verify these items in Xcode for the app target:

1. `Signing & Capabilities` still uses the intended automatic signing team.
2. Add the `iCloud` capability.
3. Enable `CloudKit`.
4. Create or select the correct default container.
5. Only then opt the app into `.automatic` CloudKit database usage in [PersistenceController.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/PersistenceController.swift).

This repo currently avoids forcing entitlement changes from code because that would be risky in a fresh project.

## Testing

The current unit tests cover:

- sample graph integrity
- projection generation for Bubble and Gantt
- bootstrap seeding behavior for in-memory SwiftData stores
- singleton preference seeding
- basic model invariant enforcement for project and step date/progress normalization

## Known Limits

- Most editing still happens directly against SwiftData models from SwiftUI views; Phase 2 reduced this, but there is not yet a dedicated mutation/service layer.
- Dependency creation and editing UI is still minimal compared with the read-side visualizations.
- The current Bubble and Gantt layouts are functional foundations, not final interaction models.

## Next 3 Sensible Steps

1. Introduce a small planning mutation layer so project, step, inbox, and dependency writes stop living in SwiftUI view files.
2. Add dependency authoring plus step reordering, then tighten validation around schedules and illegal graph links.
3. Enable CloudKit capabilities in Xcode, switch the container configuration intentionally, and test sync/merge behavior across devices.
