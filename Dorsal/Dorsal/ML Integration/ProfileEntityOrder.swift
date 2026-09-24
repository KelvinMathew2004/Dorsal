import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct ProfileEntityID: Identifiable, Hashable, Codable, Sendable, Transferable {
    let name: String
    let type: String
    var id: String { "\(type):\(name)" }
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "com.KelvinMathew.Dorsal.profile-entity", conformingTo: .data))
    }
}

nonisolated enum ProfileEntityOrder {
    static func applying(_ sources: [String], before anchor: String?, to items: [String]) -> [String] {
        var seen = Set<String>()
        let moving = sources.filter { items.contains($0) && seen.insert($0).inserted }
        guard !moving.isEmpty, anchor.map({ !moving.contains($0) }) ?? true else { return items }
        var result = items.filter { !seen.contains($0) }
        let insertion = anchor.flatMap { result.firstIndex(of: $0) } ?? result.endIndex
        result.insert(contentsOf: moving, at: insertion)
        return result
    }
}

extension DreamStore {
    func profileEntities(type: String, parentID: String? = nil, preferences: UserDefaults = .standard) -> [ProfileEntityID] {
        let entities = parentID.flatMap { id in
            getRootEntities(type: type).first { $0.id == id }.map { getChildren(for: $0.name, type: type) }
        } ?? (parentID == nil ? getRootEntities(type: type) : [])
        let key = parentID ?? "root:\(type)"
        let saved = preferences.dictionary(forKey: "profileEntityOrder") as? [String: [String]] ?? [:]
        let ranks = Dictionary((saved[key] ?? []).enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return entities.map { ProfileEntityID(name: $0.name, type: $0.type) }.sorted {
            let left = ranks[$0.id] ?? Int.max, right = ranks[$1.id] ?? Int.max
            return left == right ? $0.name < $1.name : left < right
        }
    }

    func canMoveProfileEntities(_ ids: [String], type: String, parentID: String?) -> Bool {
        guard !ids.isEmpty, ["person", "place", "tag"].contains(type) else { return false }
        let roots = getRootEntities(type: type)
        let all = roots + roots.flatMap { getChildren(for: $0.name, type: type) }
        guard ids.allSatisfy({ id in all.contains { $0.id == id } }) else { return false }
        if let parentID {
            guard !ids.contains(parentID), roots.contains(where: { $0.id == parentID }) else { return false }
            // Preserve the existing one-level grouping model; never nest a group.
            return ids.allSatisfy { id in !roots.contains { $0.id == id && !getChildren(for: $0.name, type: type).isEmpty } }
        }
        return true
    }

    @discardableResult
    func moveProfileEntities(_ ids: [String], type: String, parentID: String?, before anchor: String?, preferences: UserDefaults = .standard) -> Bool {
        guard let context = modelContext, canMoveProfileEntities(ids, type: type, parentID: parentID) else { return false }
        let roots = getRootEntities(type: type)
        let all = roots + roots.flatMap { getChildren(for: $0.name, type: type) }
        let moving = all.filter { ids.contains($0.id) }
        var destination = profileEntities(type: type, parentID: parentID, preferences: preferences).map(\.id)
        destination += ids.filter { !destination.contains($0) }
        let ordered = ProfileEntityOrder.applying(ids, before: anchor, to: destination)
        do {
            if let parentID, let parent = roots.first(where: { $0.id == parentID }), getEntity(name: parent.name, type: type) == nil {
                context.insert(parent)
            }
            for item in moving {
                if getEntity(name: item.name, type: type) == nil { context.insert(item) }
                item.parentID = parentID
                item.lastUpdated = Date()
            }
            try context.save()
            var saved = preferences.dictionary(forKey: "profileEntityOrder") as? [String: [String]] ?? [:]
            saved[parentID ?? "root:\(type)"] = ordered
            preferences.set(saved, forKey: "profileEntityOrder")
            entityUpdateTrigger += 1
            return true
        } catch {
            context.rollback()
            persistenceError = "The profile change couldn’t be saved. Please try moving the item again."
            return false
        }
    }
}

struct ProfileEntityContainer: ViewModifier {
    @ObservedObject var store: DreamStore
    let type: String
    @Binding var draggedItem: ProfileEntityID?

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content
                .reorderContainer(for: ProfileEntityID.self, in: String.self) { difference in
                    let parent = difference.destination.collectionID == "root:\(type)" ? nil : difference.destination.collectionID
                    let anchor: String? = switch difference.destination.position {
                    case .before(let id): id
                    case .end: nil
                    }
                    withAnimation {
                        _ = store.moveProfileEntities(difference.sources, type: type, parentID: parent, before: anchor)
                    }
                }
                .dragContainer(for: ProfileEntityID.self) { (ids: [String]) in
                    let roots = store.profileEntities(type: type)
                    let all = roots + roots.flatMap { store.profileEntities(type: type, parentID: $0.id) }
                    return all.filter { ids.contains($0.id) }
                }
                .dropDestination(for: ProfileEntityID.self) { items, session in
                    guard session.localSession != nil else { return }
                    withAnimation {
                        _ = store.moveProfileEntities(items.map(\.id), type: type, parentID: nil, before: nil)
                    }
                }
        } else {
            content.onDrop(of: [UTType.text], delegate: RootDropDelegate(draggedItem: $draggedItem, store: store))
        }
    }
}
