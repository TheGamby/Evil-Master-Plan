import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var status: ProjectStatus
    var priority: PriorityLevel
    var progress: Double
    var createdAt: Date
    var updatedAt: Date
    var startDate: Date?
    var dueDate: Date?
    var archivedAt: Date?
    var tags: [String]
    var colorToken: ProjectColorToken
    @Relationship(deleteRule: .cascade, inverse: \ProjectStep.project) var steps: [ProjectStep]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        status: ProjectStatus = .idea,
        priority: PriorityLevel = .medium,
        progress: Double = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        archivedAt: Date? = nil,
        tags: [String] = [],
        colorToken: ProjectColorToken = .ember,
        steps: [ProjectStep] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.priority = priority
        self.progress = min(max(progress, 0), 1)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.dueDate = dueDate
        self.archivedAt = archivedAt
        self.tags = tags
        self.colorToken = colorToken
        self.steps = steps
    }
}

extension Project {
    static func starter(title: String = "New Project", now: Date = .now) -> Project {
        Project(
            title: title,
            summary: "Define the direction, then break it into a few visible steps.",
            status: .idea,
            priority: .medium,
            progress: 0.05,
            createdAt: now,
            updatedAt: now,
            startDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: 21, to: now),
            tags: ["new"],
            colorToken: .cobalt
        )
    }

    var sortedSteps: [ProjectStep] {
        steps.sorted(using: SortDescriptor(\.sortOrder))
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var resolvedStartDate: Date? {
        startDate ?? steps.compactMap(\.startDate).min()
    }

    var resolvedDueDate: Date? {
        dueDate ?? steps.compactMap(\.dueDate).max()
    }

    var milestoneCount: Int {
        steps.filter(\.isMilestone).count
    }

    var openStepCount: Int {
        steps.filter(\.isOpen).count
    }

    var blockedStepCount: Int {
        steps.filter { $0.status == .blocked }.count
    }

    var isBlocked: Bool {
        status == .blocked || blockedStepCount > 0
    }

    var nextMilestones: [ProjectStep] {
        sortedSteps
            .filter { $0.isMilestone && $0.status != .done }
            .sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    var isHighPriority: Bool {
        priority.isHighPriority
    }

    func touch(at date: Date = .now) {
        updatedAt = date
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

    func setTags(from rawValue: String) {
        tags = Self.normalizedTags(from: rawValue)
        touch()
    }

    @discardableResult
    func addStep(
        title: String = "New Step",
        notes: String = "",
        status: ProjectStatus = .idea,
        priority: PriorityLevel = .medium,
        progress: Double = 0,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        kind: ProjectStepKind = .task
    ) -> ProjectStep {
        let step = ProjectStep(
            project: self,
            title: title,
            notes: notes,
            status: status,
            priority: priority,
            progress: progress,
            startDate: startDate ?? self.startDate,
            dueDate: dueDate ?? self.dueDate,
            sortOrder: nextSortOrder,
            kind: kind
        )
        steps.append(step)
        touch()
        return step
    }

    @discardableResult
    func addMilestone(title: String = "New Milestone") -> ProjectStep {
        let milestoneDate = dueDate ?? startDate ?? .now
        return addStep(
            title: title,
            notes: "",
            status: .idea,
            priority: .high,
            progress: 0,
            startDate: milestoneDate,
            dueDate: milestoneDate,
            kind: .milestone
        )
    }

    func mergeTags(_ incomingTags: [String]) {
        tags = Self.normalizedTags(tags + incomingTags)
        touch()
    }

    func archive(at date: Date = .now) {
        archivedAt = date
        touch(at: date)
    }

    func restoreFromArchive(at date: Date = .now) {
        archivedAt = nil
        touch(at: date)
    }

    @discardableResult
    func moveStep(_ step: ProjectStep, direction: StepMoveDirection, at date: Date = .now) -> Bool {
        var orderedSteps = sortedSteps
        guard let currentIndex = orderedSteps.firstIndex(where: { $0.id == step.id }) else {
            return false
        }

        let targetIndex: Int
        switch direction {
        case .earlier:
            targetIndex = currentIndex - 1
        case .later:
            targetIndex = currentIndex + 1
        }

        guard orderedSteps.indices.contains(targetIndex) else {
            return false
        }

        let movingStep = orderedSteps.remove(at: currentIndex)
        orderedSteps.insert(movingStep, at: targetIndex)
        normalizeStepOrder(orderedSteps)
        touch(at: date)
        return true
    }

    func canMoveStep(_ step: ProjectStep, direction: StepMoveDirection) -> Bool {
        guard let currentIndex = sortedSteps.firstIndex(where: { $0.id == step.id }) else {
            return false
        }

        switch direction {
        case .earlier:
            return currentIndex > 0
        case .later:
            return currentIndex < sortedSteps.count - 1
        }
    }

    func normalizeStepOrder(at date: Date = .now) {
        normalizeStepOrder(sortedSteps)
        touch(at: date)
    }

    private var nextSortOrder: Double {
        (steps.map(\.sortOrder).max() ?? -1) + 1
    }

    private func normalizeSchedule() {
        guard let startDate, let dueDate, dueDate < startDate else {
            return
        }
        self.dueDate = startDate
    }

    private func normalizeStepOrder(_ orderedSteps: [ProjectStep]) {
        for (index, step) in orderedSteps.enumerated() {
            step.sortOrder = Double(index)
        }
    }

    private static func normalizedTags(from rawValue: String) -> [String] {
        normalizedTags(
            rawValue
                .split(separator: ",")
                .map { String($0) }
        )
    }

    private static func normalizedTags(_ rawTags: [String]) -> [String] {
        var seen = Set<String>()

        return rawTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}
