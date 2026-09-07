import Foundation

enum FolderCompareStatus: String, Equatable {
    case same
    case onlyLeft
    case onlyRight
    case newerLeft
    case newerRight
    case different

    var isDifference: Bool {
        self != .same
    }
}

struct FolderCompareEntry: Equatable {
    let name: String
    let left: FileItem?
    let right: FileItem?
    let status: FolderCompareStatus
}

struct FolderCompareSummary: Equatable {
    var same = 0
    var onlyLeft = 0
    var onlyRight = 0
    var newerLeft = 0
    var newerRight = 0
    var different = 0

    var differingCount: Int {
        onlyLeft + onlyRight + newerLeft + newerRight + different
    }

    var compactText: String {
        if differingCount == 0 { return "All items match" }
        return "\(differingCount) difference\(differingCount == 1 ? "" : "s")"
    }

    var detailText: String {
        if differingCount == 0 { return "Compare: all items match" }

        var parts: [String] = []
        if onlyLeft > 0 { parts.append("\(onlyLeft) left only") }
        if onlyRight > 0 { parts.append("\(onlyRight) right only") }
        if newerLeft > 0 { parts.append("\(newerLeft) newer left") }
        if newerRight > 0 { parts.append("\(newerRight) newer right") }
        if different > 0 { parts.append("\(different) different") }
        return "Compare: " + parts.joined(separator: ", ")
    }
}

struct FolderCompareSnapshot: Equatable {
    let entries: [FolderCompareEntry]
    let summary: FolderCompareSummary
    let leftStatuses: [URL: FolderCompareStatus]
    let rightStatuses: [URL: FolderCompareStatus]

    var hasDifferences: Bool {
        summary.differingCount > 0
    }
}

enum FolderSyncDirection: String, Equatable {
    case leftToRight
    case rightToLeft

    var label: String {
        switch self {
        case .leftToRight: return "Left to Right"
        case .rightToLeft: return "Right to Left"
        }
    }
}

enum FolderSyncAction: Equatable {
    case copyMissing
    case overwriteOlder
    case overwriteDifferent
}

struct FolderSyncPlanEntry: Equatable {
    let source: FileItem
    let destination: URL
    let action: FolderSyncAction
}

struct FolderSyncPlan: Equatable {
    let direction: FolderSyncDirection
    let sourceFolder: URL
    let destinationFolder: URL
    let entries: [FolderSyncPlanEntry]
    let skippedExistingFolderOverwrites: Int

    var isEmpty: Bool {
        entries.isEmpty
    }

    var copyMissingCount: Int {
        entries.filter { $0.action == .copyMissing }.count
    }

    var overwriteOlderCount: Int {
        entries.filter { $0.action == .overwriteOlder }.count
    }

    var overwriteDifferentCount: Int {
        entries.filter { $0.action == .overwriteDifferent }.count
    }

    var overwriteCount: Int {
        overwriteOlderCount + overwriteDifferentCount
    }

    var confirmationMessage: String {
        var parts: [String] = []
        if copyMissingCount > 0 {
            parts.append("copy \(copyMissingCount) missing item\(copyMissingCount == 1 ? "" : "s")")
        }
        if overwriteOlderCount > 0 {
            parts.append("overwrite \(overwriteOlderCount) older file\(overwriteOlderCount == 1 ? "" : "s")")
        }
        if overwriteDifferentCount > 0 {
            parts.append("overwrite \(overwriteDifferentCount) different file\(overwriteDifferentCount == 1 ? "" : "s")")
        }

        let actionText = parts.isEmpty ? "make no filesystem changes" : parts.joined(separator: ", ")
        var message = "Sync \(direction.label)? This will \(actionText). Destination-only items will not be deleted."
        if skippedExistingFolderOverwrites > 0 {
            message += " \(skippedExistingFolderOverwrites) existing folder difference\(skippedExistingFolderOverwrites == 1 ? "" : "s") will be skipped."
        }
        return message
    }
}

enum FolderCompareService {
    private static let dateTolerance: TimeInterval = 1

    static func compare(leftItems: [FileItem], rightItems: [FileItem]) -> FolderCompareSnapshot {
        let leftByName = Dictionary(leftItems.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let rightByName = Dictionary(rightItems.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let names = Set(leftByName.keys).union(rightByName.keys).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        var summary = FolderCompareSummary()
        var leftStatuses: [URL: FolderCompareStatus] = [:]
        var rightStatuses: [URL: FolderCompareStatus] = [:]

        let entries = names.map { name -> FolderCompareEntry in
            let left = leftByName[name]
            let right = rightByName[name]
            let status = status(left: left, right: right)

            switch status {
            case .same: summary.same += 1
            case .onlyLeft: summary.onlyLeft += 1
            case .onlyRight: summary.onlyRight += 1
            case .newerLeft: summary.newerLeft += 1
            case .newerRight: summary.newerRight += 1
            case .different: summary.different += 1
            }

            if status.isDifference, let left {
                leftStatuses[left.url] = status
            }
            if status.isDifference, let right {
                rightStatuses[right.url] = status
            }

            return FolderCompareEntry(name: name, left: left, right: right, status: status)
        }

        return FolderCompareSnapshot(
            entries: entries,
            summary: summary,
            leftStatuses: leftStatuses,
            rightStatuses: rightStatuses
        )
    }

    static func syncPlan(
        from snapshot: FolderCompareSnapshot,
        direction: FolderSyncDirection,
        leftFolder: URL,
        rightFolder: URL
    ) -> FolderSyncPlan {
        let sourceFolder = direction == .leftToRight ? leftFolder : rightFolder
        let destinationFolder = direction == .leftToRight ? rightFolder : leftFolder
        var entries: [FolderSyncPlanEntry] = []
        var skippedExistingFolderOverwrites = 0

        for entry in snapshot.entries {
            guard let planEntry = syncPlanEntry(
                for: entry,
                direction: direction,
                destinationFolder: destinationFolder,
                skippedExistingFolderOverwrites: &skippedExistingFolderOverwrites
            ) else {
                continue
            }
            entries.append(planEntry)
        }

        return FolderSyncPlan(
            direction: direction,
            sourceFolder: sourceFolder,
            destinationFolder: destinationFolder,
            entries: entries,
            skippedExistingFolderOverwrites: skippedExistingFolderOverwrites
        )
    }

    private static func status(left: FileItem?, right: FileItem?) -> FolderCompareStatus {
        guard let left else { return right == nil ? .same : .onlyRight }
        guard let right else { return .onlyLeft }

        // For directories, skip kind comparison: iCloud Drive reports "iCloud Folder"
        // instead of "Folder" for the same directory, causing false .different results.
        let kindMatches = left.isDirectory || left.kind == right.kind
        guard left.isDirectory == right.isDirectory,
              kindMatches,
              left.size == right.size else {
            return .different
        }
        guard (left.modified == nil) == (right.modified == nil) else {
            return .different
        }

        switch compareDates(left.modified, right.modified) {
        case .orderedSame:
            return .same
        case .orderedDescending:
            return .newerLeft
        case .orderedAscending:
            return .newerRight
        }
    }

    private static func compareDates(_ left: Date?, _ right: Date?) -> ComparisonResult {
        switch (left, right) {
        case (.none, .none):
            return .orderedSame
        case let (.some(leftDate), .some(rightDate)):
            let delta = leftDate.timeIntervalSince(rightDate)
            if abs(delta) <= dateTolerance { return .orderedSame }
            return delta > 0 ? .orderedDescending : .orderedAscending
        default:
            return .orderedSame
        }
    }

    private static func syncPlanEntry(
        for entry: FolderCompareEntry,
        direction: FolderSyncDirection,
        destinationFolder: URL,
        skippedExistingFolderOverwrites: inout Int
    ) -> FolderSyncPlanEntry? {
        switch (direction, entry.status) {
        case (.leftToRight, .onlyLeft):
            guard let source = entry.left else { return nil }
            return FolderSyncPlanEntry(
                source: source,
                destination: destinationFolder.appendingPathComponent(source.name),
                action: .copyMissing
            )
        case (.rightToLeft, .onlyRight):
            guard let source = entry.right else { return nil }
            return FolderSyncPlanEntry(
                source: source,
                destination: destinationFolder.appendingPathComponent(source.name),
                action: .copyMissing
            )
        case (.leftToRight, .newerLeft):
            return overwritingEntry(
                source: entry.left,
                destination: entry.right,
                action: .overwriteOlder,
                skippedExistingFolderOverwrites: &skippedExistingFolderOverwrites
            )
        case (.rightToLeft, .newerRight):
            return overwritingEntry(
                source: entry.right,
                destination: entry.left,
                action: .overwriteOlder,
                skippedExistingFolderOverwrites: &skippedExistingFolderOverwrites
            )
        case (.leftToRight, .different):
            return overwritingEntry(
                source: entry.left,
                destination: entry.right,
                action: .overwriteDifferent,
                skippedExistingFolderOverwrites: &skippedExistingFolderOverwrites
            )
        case (.rightToLeft, .different):
            return overwritingEntry(
                source: entry.right,
                destination: entry.left,
                action: .overwriteDifferent,
                skippedExistingFolderOverwrites: &skippedExistingFolderOverwrites
            )
        default:
            return nil
        }
    }

    private static func overwritingEntry(
        source: FileItem?,
        destination: FileItem?,
        action: FolderSyncAction,
        skippedExistingFolderOverwrites: inout Int
    ) -> FolderSyncPlanEntry? {
        guard let source, let destination else { return nil }
        guard !source.isDirectory, !destination.isDirectory else {
            skippedExistingFolderOverwrites += 1
            return nil
        }
        return FolderSyncPlanEntry(source: source, destination: destination.url, action: action)
    }
}
