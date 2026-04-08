import CoreGraphics
import Foundation

struct BubbleDraftGroup {
    let id: String
    let title: String
    let rank: Int
}

struct BubbleDraftNode {
    let id: UUID
    let sourceReference: PlanningItemReference
    let title: String
    let subtitle: String?
    let kind: BubbleNodeKind
    let status: ProjectStatus
    let priority: PriorityLevel
    let progress: Double
    let dueDate: Date?
    let colorToken: ProjectColorToken
    let radius: CGFloat
    let openStepCount: Int
    let dependencyCount: Int
    let isBlocked: Bool
    let isFocused: Bool
    let isSelected: Bool
    let isConnectedToSelection: Bool
    let isDimmed: Bool
    let groupID: String
    let groupTitle: String
    let groupRank: Int
    let clusterParentID: UUID?
}

struct BubbleDraftEdge {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let type: DependencyType
    let weight: Double
    let isHighlighted: Bool
}

struct BubbleGraphDraft {
    let nodes: [BubbleDraftNode]
    let edges: [BubbleDraftEdge]
    let groups: [BubbleDraftGroup]
}

enum BubbleGraphLayoutEngine {
    static func layout(draft: BubbleGraphDraft, viewportWidth: CGFloat) -> BubbleGraph {
        let projectNodes = draft.nodes.filter { $0.clusterParentID == nil }
        let childNodes = draft.nodes.filter { $0.clusterParentID != nil }
        let sortedGroups = draft.groups.sorted {
            if $0.rank == $1.rank {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.rank < $1.rank
        }

        let groupCount = max(sortedGroups.count, 1)
        let columns = max(1, Int(ceil(sqrt(Double(groupCount)))))
        let largestProjectRadius = projectNodes.map(\.radius).max() ?? 54
        let cellWidth = max(360, largestProjectRadius * 5.4)
        let cellHeight = max(340, largestProjectRadius * 5.0)
        let canvasWidth = max(viewportWidth, CGFloat(columns) * cellWidth + 120)

        var groupFrames: [String: CGRect] = [:]
        var positions: [UUID: CGPoint] = [:]
        var groups: [BubbleGroup] = []

        for (index, group) in sortedGroups.enumerated() {
            let row = index / columns
            let column = index % columns
            let frame = CGRect(
                x: 60 + CGFloat(column) * cellWidth,
                y: 80 + CGFloat(row) * cellHeight,
                width: cellWidth - 32,
                height: cellHeight - 28
            )
            groupFrames[group.id] = frame

            let nodes = projectNodes
                .filter { $0.groupID == group.id }
                .sorted(by: BubbleNodeDraftSort.compare)
            let centerNodeID = nodes.first(where: \.isFocused)?.id
            positions.merge(
                clusteredPositions(
                    for: nodes,
                    around: CGPoint(x: frame.midX, y: frame.midY + 12),
                    baseRadius: max(largestProjectRadius + 22, 72),
                    centerNodeID: centerNodeID
                ),
                uniquingKeysWith: { _, new in new }
            )

            groups.append(
                BubbleGroup(
                    id: group.id,
                    title: group.title,
                    frame: frame,
                    nodeCount: nodes.count
                )
            )
        }

        let projectRadii = Dictionary(uniqueKeysWithValues: projectNodes.map { ($0.id, $0.radius) })

        let childrenByParent = Dictionary(grouping: childNodes, by: \.clusterParentID)
        for (parentID, children) in childrenByParent {
            guard
                let resolvedParentID = parentID,
                let parentCenter = positions[resolvedParentID]
            else {
                continue
            }

            let parentRadius = projectRadii[resolvedParentID] ?? 64
            let childBaseRadius = parentRadius + (children.map(\.radius).max() ?? 30) + 56
            positions.merge(
                clusteredPositions(
                    for: children.sorted(by: BubbleNodeDraftSort.compare),
                    around: parentCenter,
                    baseRadius: childBaseRadius,
                    centerNodeID: nil
                ),
                uniquingKeysWith: { _, new in new }
            )
        }

        let nodes = draft.nodes.map { node in
            BubbleNode(
                id: node.id,
                sourceReference: node.sourceReference,
                title: node.title,
                subtitle: node.subtitle,
                kind: node.kind,
                status: node.status,
                priority: node.priority,
                progress: node.progress,
                dueDate: node.dueDate,
                colorToken: node.colorToken,
                position: positions[node.id] ?? .zero,
                radius: node.radius,
                openStepCount: node.openStepCount,
                dependencyCount: node.dependencyCount,
                isBlocked: node.isBlocked,
                isFocused: node.isFocused,
                isSelected: node.isSelected,
                isConnectedToSelection: node.isConnectedToSelection,
                isDimmed: node.isDimmed,
                groupID: node.groupID,
                groupTitle: node.groupTitle,
                clusterParentID: node.clusterParentID
            )
        }

        let nodeBounds = nodes.map {
            CGRect(
                x: $0.position.x - $0.radius,
                y: $0.position.y - $0.radius,
                width: $0.radius * 2,
                height: $0.radius * 2
            )
        }

        let groupBounds = groups.map(\.frame)
        let allBounds = nodeBounds + groupBounds
        let maxX = allBounds.map(\.maxX).max() ?? canvasWidth
        let maxY = allBounds.map(\.maxY).max() ?? 540
        let canvasSize = CGSize(width: max(canvasWidth, maxX + 80), height: maxY + 80)

        let edges = draft.edges.map {
            BubbleEdge(
                id: $0.id,
                sourceNodeID: $0.sourceNodeID,
                targetNodeID: $0.targetNodeID,
                type: $0.type,
                weight: $0.weight,
                isHighlighted: $0.isHighlighted
            )
        }

        return BubbleGraph(nodes: nodes, edges: edges, groups: groups, canvasSize: canvasSize)
    }

    private static func clusteredPositions(
        for nodes: [BubbleDraftNode],
        around center: CGPoint,
        baseRadius: CGFloat,
        centerNodeID: UUID?
    ) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else {
            return [:]
        }

        var remaining = nodes
        var positions: [UUID: CGPoint] = [:]

        if let centerNodeID {
            if let index = remaining.firstIndex(where: { $0.id == centerNodeID }) {
                let centerNode = remaining.remove(at: index)
                positions[centerNode.id] = center
            }
        } else if remaining.count == 1 {
            let node = remaining.removeFirst()
            positions[node.id] = center
        }

        guard !remaining.isEmpty else {
            return positions
        }

        let averageDiameter = max(
            remaining.map { $0.radius * 2 }.reduce(0, +) / CGFloat(max(remaining.count, 1)),
            84
        )
        let ringSpacing = max(averageDiameter + 30, 108)

        var offset = 0
        var ringIndex = 0
        while offset < remaining.count {
            ringIndex += 1
            let ringRadius = baseRadius + CGFloat(ringIndex - 1) * ringSpacing
            let capacity = max(1, Int(floor((2 * .pi * ringRadius) / (averageDiameter + 22))))
            let slice = Array(remaining.dropFirst(offset).prefix(capacity))

            for (sliceIndex, node) in slice.enumerated() {
                let angle = (-CGFloat.pi / 2) + (CGFloat(sliceIndex) / CGFloat(max(slice.count, 1))) * (2 * .pi)
                positions[node.id] = CGPoint(
                    x: center.x + cos(angle) * ringRadius,
                    y: center.y + sin(angle) * ringRadius
                )
            }

            offset += slice.count
        }

        return positions
    }
}

private enum BubbleNodeDraftSort {
    nonisolated static func compare(_ lhs: BubbleDraftNode, _ rhs: BubbleDraftNode) -> Bool {
        if lhs.isFocused != rhs.isFocused {
            return lhs.isFocused
        }
        if lhs.isBlocked != rhs.isBlocked {
            return lhs.isBlocked
        }
        if lhs.priority != rhs.priority {
            return priorityOrder(lhs.priority) > priorityOrder(rhs.priority)
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    nonisolated static func priorityOrder(_ priority: PriorityLevel) -> Int {
        switch priority {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        case .urgent:
            3
        }
    }
}
