import Foundation
import SwiftData

@Model
final class IdeaInboxItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var state: IdeaInboxState
    @Attribute(originalName: "tags") var tagsStorage: [String]?
    var priorityHint: PriorityLevel?
    var source: IdeaInboxSource?
    var convertedAt: Date?
    var archivedAt: Date?
    var conversionTarget: IdeaInboxConversionTarget?
    @Relationship var linkedProject: Project?
    @Relationship var linkedStep: ProjectStep?

    init(
        id: UUID = UUID(),
        title: String,
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        state: IdeaInboxState = .open,
        tags: [String] = [],
        priorityHint: PriorityLevel? = nil,
        source: IdeaInboxSource? = .manualCapture,
        convertedAt: Date? = nil,
        archivedAt: Date? = nil,
        conversionTarget: IdeaInboxConversionTarget? = nil,
        linkedProject: Project? = nil,
        linkedStep: ProjectStep? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.tagsStorage = Self.normalizedTags(tags)
        self.priorityHint = priorityHint
        self.source = source
        self.convertedAt = convertedAt
        self.archivedAt = archivedAt
        self.conversionTarget = conversionTarget
        self.linkedProject = linkedProject
        self.linkedStep = linkedStep
    }
}

extension IdeaInboxItem {
    var tags: [String] {
        get { tagsStorage ?? [] }
        set { tagsStorage = Self.normalizedTags(newValue) }
    }

    var canConvert: Bool {
        state.needsTriage
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var convertedTargetTitle: String? {
        if let linkedStep {
            return linkedStep.title
        }

        return linkedProject?.title
    }

    func touch(at date: Date = .now) {
        updatedAt = date
    }

    func markReviewing(at date: Date = .now) {
        state = .reviewing
        archivedAt = nil
        touch(at: date)
    }

    func reopen(at date: Date = .now) {
        state = .open
        archivedAt = nil
        touch(at: date)
    }

    func archive(at date: Date = .now) {
        state = .archived
        archivedAt = date
        touch(at: date)
    }

    func setTags(from rawValue: String) {
        tags = rawValue
            .split(separator: ",")
            .map { String($0) }
        touch()
    }

    func markConverted(
        target: IdeaInboxConversionTarget,
        project: Project,
        step: ProjectStep? = nil,
        at date: Date = .now
    ) {
        state = .converted
        convertedAt = date
        archivedAt = nil
        conversionTarget = target
        linkedProject = project
        linkedStep = step
        touch(at: date)
    }

    func unlinkDeletedTarget(at date: Date = .now) {
        state = .reviewing
        convertedAt = nil
        archivedAt = nil
        conversionTarget = nil
        linkedProject = nil
        linkedStep = nil
        touch(at: date)
    }

    private static func normalizedTags(_ rawTags: [String]) -> [String]? {
        var seen = Set<String>()
        let normalized = rawTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }

        return normalized.isEmpty ? nil : normalized
    }
}
