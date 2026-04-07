import Foundation
import SwiftData

struct SeedSnapshot {
    let projects: [Project]
    let dependencies: [Dependency]
    let inboxItems: [IdeaInboxItem]
    let preferences: VisualizationPreferences
}

enum SeedData {
    static func installSampleContent(
        in context: ModelContext,
        now: Date = .now,
        includePreferences: Bool = true
    ) {
        let snapshot = makeSampleSnapshot(now: now)
        snapshot.projects.forEach(context.insert)
        snapshot.dependencies.forEach(context.insert)
        snapshot.inboxItems.forEach(context.insert)
        if includePreferences {
            context.insert(snapshot.preferences)
        }
    }

    static func makeSampleSnapshot(now: Date = .now) -> SeedSnapshot {
        let calendar = Calendar.current

        let atlas = Project(
            title: "Atlas Launch System",
            summary: "Ship the first durable planning release with visual navigation and a calm editing flow.",
            status: .active,
            priority: .urgent,
            progress: 0.62,
            createdAt: calendar.date(byAdding: .day, value: -35, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            startDate: calendar.date(byAdding: .day, value: -28, to: now),
            dueDate: calendar.date(byAdding: .day, value: 14, to: now),
            tags: ["release", "product"],
            colorToken: .ember
        )

        let atlasResearch = ProjectStep(
            project: atlas,
            title: "Lock core interaction model",
            notes: "Define the primary capture, browse, and focus loops.",
            status: .done,
            priority: .high,
            progress: 1,
            startDate: calendar.date(byAdding: .day, value: -26, to: now),
            dueDate: calendar.date(byAdding: .day, value: -18, to: now),
            sortOrder: 0
        )
        let atlasPrototype = ProjectStep(
            project: atlas,
            title: "Build adaptive app shell",
            notes: "Sidebar on macOS and roomy iPad layout without losing iPhone speed.",
            status: .active,
            priority: .urgent,
            progress: 0.72,
            startDate: calendar.date(byAdding: .day, value: -16, to: now),
            dueDate: calendar.date(byAdding: .day, value: 1, to: now),
            sortOrder: 1
        )
        let atlasBeta = ProjectStep(
            project: atlas,
            title: "Internal beta milestone",
            notes: "First workflow-complete milestone.",
            status: .active,
            priority: .urgent,
            progress: 0.35,
            startDate: calendar.date(byAdding: .day, value: 2, to: now),
            dueDate: calendar.date(byAdding: .day, value: 7, to: now),
            sortOrder: 2,
            kind: .milestone
        )
        atlas.steps = [atlasResearch, atlasPrototype, atlasBeta]

        let pulse = Project(
            title: "Pulse Dashboard",
            summary: "Create a daily focus surface that feels more like a cockpit than admin software.",
            status: .active,
            priority: .high,
            progress: 0.38,
            createdAt: calendar.date(byAdding: .day, value: -21, to: now) ?? now,
            updatedAt: now,
            startDate: calendar.date(byAdding: .day, value: -10, to: now),
            dueDate: calendar.date(byAdding: .day, value: 18, to: now),
            tags: ["dashboard", "focus"],
            colorToken: .cyan
        )

        let pulseToday = ProjectStep(
            project: pulse,
            title: "Design today's focus card",
            notes: "Needs urgency, context, and next action without clutter.",
            status: .active,
            priority: .high,
            progress: 0.5,
            startDate: calendar.date(byAdding: .day, value: -8, to: now),
            dueDate: calendar.date(byAdding: .day, value: 4, to: now),
            sortOrder: 0
        )
        let pulseSignals = ProjectStep(
            project: pulse,
            title: "Choose dashboard signals",
            notes: "Active projects, blocked work, inbox pressure, and upcoming milestones.",
            status: .idea,
            priority: .medium,
            progress: 0.1,
            startDate: calendar.date(byAdding: .day, value: 5, to: now),
            dueDate: calendar.date(byAdding: .day, value: 11, to: now),
            sortOrder: 1
        )
        pulse.steps = [pulseToday, pulseSignals]

        let lattice = Project(
            title: "Dependency Lattice",
            summary: "Make sequencing visible without forcing full PM ceremony.",
            status: .blocked,
            priority: .high,
            progress: 0.24,
            createdAt: calendar.date(byAdding: .day, value: -14, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            startDate: calendar.date(byAdding: .day, value: -4, to: now),
            dueDate: calendar.date(byAdding: .day, value: 28, to: now),
            tags: ["dependencies", "timeline"],
            colorToken: .lime
        )

        let latticeModel = ProjectStep(
            project: lattice,
            title: "Normalize dependency model",
            notes: "Shared references for project and step links.",
            status: .done,
            priority: .high,
            progress: 1,
            startDate: calendar.date(byAdding: .day, value: -4, to: now),
            dueDate: calendar.date(byAdding: .day, value: -1, to: now),
            sortOrder: 0
        )
        let latticeRendering = ProjectStep(
            project: lattice,
            title: "Render arrow timeline",
            notes: "Needs clean labels and a low-noise layout.",
            status: .blocked,
            priority: .high,
            progress: 0.2,
            startDate: calendar.date(byAdding: .day, value: 3, to: now),
            dueDate: calendar.date(byAdding: .day, value: 16, to: now),
            sortOrder: 1
        )
        lattice.steps = [latticeModel, latticeRendering]

        let sketchbook = Project(
            title: "Sketchbook Intake",
            summary: "Keep rough ideas frictionless until they deserve structure.",
            status: .idea,
            priority: .medium,
            progress: 0.14,
            createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            updatedAt: now,
            startDate: now,
            dueDate: calendar.date(byAdding: .day, value: 10, to: now),
            tags: ["inbox", "capture"],
            colorToken: .rose
        )

        let sketchRefine = ProjectStep(
            project: sketchbook,
            title: "Define inbox-to-project handoff",
            notes: "Keep it one-tap where possible.",
            status: .idea,
            priority: .medium,
            progress: 0.1,
            startDate: now,
            dueDate: calendar.date(byAdding: .day, value: 6, to: now),
            sortOrder: 0
        )
        sketchbook.steps = [sketchRefine]

        let dependencies = [
            Dependency(
                sourceKind: .step,
                sourceItemID: atlasResearch.id,
                targetKind: .step,
                targetItemID: atlasPrototype.id,
                type: .finishToStart,
                note: "Interaction decisions guide shell structure."
            ),
            Dependency(
                sourceKind: .step,
                sourceItemID: atlasPrototype.id,
                targetKind: .step,
                targetItemID: atlasBeta.id,
                type: .finishToStart,
                note: "Beta only makes sense once navigation and editing hold together."
            ),
            Dependency(
                sourceKind: .step,
                sourceItemID: latticeModel.id,
                targetKind: .step,
                targetItemID: latticeRendering.id,
                type: .finishToStart,
                note: "Rendering depends on the shared model reference scheme."
            ),
            Dependency(
                sourceKind: .project,
                sourceItemID: pulse.id,
                targetKind: .project,
                targetItemID: atlas.id,
                type: .startToStart,
                note: "The dashboard evolves in parallel with the release shell."
            ),
        ]

        let inboxItems = [
            IdeaInboxItem(
                title: "Quick-capture from Share Sheet",
                body: "Long term: send links, text snippets, and screenshots directly into Inbox.",
                createdAt: calendar.date(byAdding: .hour, value: -18, to: now) ?? now
            ),
            IdeaInboxItem(
                title: "Energy-aware focus mode",
                body: "Surface only two meaningful next actions when attention is low.",
                createdAt: calendar.date(byAdding: .hour, value: -7, to: now) ?? now
            ),
            IdeaInboxItem(
                title: "Voice memo intake",
                body: "Capture raw planning thoughts while walking, transcribe later.",
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now
            ),
        ]

        return SeedSnapshot(
            projects: [atlas, pulse, lattice, sketchbook],
            dependencies: dependencies,
            inboxItems: inboxItems,
            preferences: VisualizationPreferences(
                bubbleSizingCriterion: .priority,
                projectSortCriterion: .updatedAt,
                showsCompletedItems: true,
                showsOnlyHighPriorityProjects: false
            )
        )
    }
}
