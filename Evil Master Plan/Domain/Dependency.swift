import Foundation
import SwiftData

struct PlanningItemReference: Hashable {
    let kind: PlanningItemKind
    let id: UUID
}

@Model
final class Dependency {
    @Attribute(.unique) var id: UUID
    var sourceKind: PlanningItemKind
    var sourceItemID: UUID
    var targetKind: PlanningItemKind
    var targetItemID: UUID
    var type: DependencyType
    var note: String

    init(
        id: UUID = UUID(),
        sourceKind: PlanningItemKind,
        sourceItemID: UUID,
        targetKind: PlanningItemKind,
        targetItemID: UUID,
        type: DependencyType = .finishToStart,
        note: String = ""
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.sourceItemID = sourceItemID
        self.targetKind = targetKind
        self.targetItemID = targetItemID
        self.type = type
        self.note = note
    }
}

extension Dependency {
    var sourceReference: PlanningItemReference {
        PlanningItemReference(kind: sourceKind, id: sourceItemID)
    }

    var targetReference: PlanningItemReference {
        PlanningItemReference(kind: targetKind, id: targetItemID)
    }

    var isSelfReference: Bool {
        sourceKind == targetKind && sourceItemID == targetItemID
    }
}
