# Evil Master Plan

Evil Master Plan is a SwiftUI multiplatform planning app for macOS, iPadOS, and iPhone. It is designed for visually driven, parallel project work: many active projects, many steps, visible dependencies, and fast capture without turning into admin software.

## Current Goal

This repository now contains a pragmatic production-ready foundation:

- one shared planning model
- SwiftData-backed local persistence
- an adaptive app shell for macOS, iPadOS, and iPhone
- first real screens for Projects, Inbox, Bubble Network, Gantt, Dependencies, Dashboard, and Settings
- seed data and previews so the app is immediately explorable

## Architecture

The app uses one central domain model and multiple projection layers:

- Persistent core models: `Project`, `ProjectStep`, `Dependency`, `IdeaInboxItem`, `ViewPreferences`
- Shared projection types: `BubbleNetworkProjection`, `GanttProjection`, `DependencyRowProjection`, `DashboardSnapshot`
- SwiftUI feature screens read the same stored models and render different representations

This is the key architectural decision: Bubble, Gantt, and Dependency views do not own separate data worlds.

### Why SwiftData

SwiftData is used because the app needs:

- local-first persistence with minimal glue code
- direct integration into SwiftUI and previews
- a path toward CloudKit/iCloud sync later

The persistence setup is centralized in [PersistenceController.swift](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data/PersistenceController.swift), so storage concerns stay out of feature views.

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

### `ViewPreferences`

- bubble sizing criterion
- default project sort
- timeline visibility preferences

## Folder Structure

- [App](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/App)
- [Domain](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Domain)
- [Data](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Data)
- [Features/Dashboard](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dashboard)
- [Features/Projects](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Projects)
- [Features/Inbox](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Inbox)
- [Features/BubbleNetwork](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/BubbleNetwork)
- [Features/Gantt](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Gantt)
- [Features/Dependencies](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Dependencies)
- [Features/Settings](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Features/Settings)
- [DesignSystem](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/DesignSystem)
- [Shared](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/Shared)
- [PreviewSupport](/Volumes/Development/source/gamby/Evil Master Plan/Evil Master Plan/PreviewSupport)

## Current Implementation Status

Implemented now:

- normal `WindowGroup` app shell instead of the document-based Xcode template
- central SwiftData container
- initial sample data bootstrap for first launch and previews
- project list plus inline project/step editing
- fast inbox capture and project promotion
- first bubble graph with dependency lines and preference-driven node size
- first Gantt timeline with bars and milestone markers
- first dependency screen with shared-link rendering
- dashboard summary and settings groundwork

Prepared but intentionally still minimal:

- CloudKit sync activation
- richer dependency graph layouts and critical-chain logic
- force-directed bubble layout
- advanced validation and conflict handling
- focus/day-planning workflows beyond the first dashboard

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

The unit tests cover:

- sample graph integrity
- projection generation for Bubble and Gantt
- bootstrap seeding behavior for in-memory SwiftData stores

## Next 3 Sensible Steps

1. Add dedicated project and step detail flows with validation, step reordering, and richer editing affordances.
2. Replace the simple bubble layout and dependency list with a real graph engine and interactive selection/highlighting.
3. Add CloudKit capability setup, then test multi-device sync and merge behavior before broadening the model further.
