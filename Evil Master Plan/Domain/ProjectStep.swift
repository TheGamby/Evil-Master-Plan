import Foundation
import SwiftData

@Model
final class ProjectStep {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var status: ProjectStatus
    var priority: PriorityLevel
    var progress: Double
    var startDate: Date?
    var dueDate: Date?
    var sortOrder: Double
    var kind: ProjectStepKind
    @Relationship var project: Project?

    init(
        id: UUID = UUID(),
        project: Project? = nil,
        title: String,
        notes: String = "",
        status: ProjectStatus = .idea,
        priority: PriorityLevel = .medium,
        progress: Double = 0,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        sortOrder: Double = 0,
        kind: ProjectStepKind = .task
    ) {
        self.id = id
        self.project = project
        self.title = title
        self.notes = notes
        self.status = status
        self.priority = priority
        self.progress = min(max(progress, 0), 1)
        self.startDate = startDate
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.kind = kind
    }
}

extension ProjectStep {
    var isOpen: Bool {
        status.isOpen
    }

    var isMilestone: Bool {
        kind == .milestone
    }

    var isHighPriority: Bool {
        priority.isHighPriority
    }

    func setProgress(_ value: Double) {
        progress = min(max(value, 0), 1)

        if progress >= 0.999 {
            status = .done
        } else if status == .done {
            status = .active
        }

        touch()
    }

    func setStatus(_ value: ProjectStatus, at date: Date = .now) {
        status = value

        if value == .done {
            progress = 1
        } else if progress >= 0.999 {
            progress = 0.9
        }

        touch(at: date)
    }

    func setPriority(_ value: PriorityLevel, at date: Date = .now) {
        priority = value
        touch(at: date)
    }

    func setKind(_ value: ProjectStepKind, at date: Date = .now) {
        kind = value

        if value == .milestone {
            if let dueDate {
                startDate = dueDate
            } else if let startDate {
                dueDate = startDate
            }
        }

        normalizeSchedule()
        touch(at: date)
    }

    func setStartDate(_ value: Date?) {
        startDate = value
        normalizeSchedule()
        touch()
    }

    func setDueDate(_ value: Date?) {
        dueDate = value
        normalizeSchedule()
        touch()
    }

    func touch(at date: Date = .now) {
        project?.touch(at: date)
    }

    private func normalizeSchedule() {
        guard let startDate, let dueDate, dueDate < startDate else {
            return
        }
        self.dueDate = startDate
    }
}
