import Foundation
import SwiftUI

private struct PromptStoreSnapshot: Codable {
    var categories: [PromptCategory]
    var prompts: [PromptDocument]
    var selectedPromptID: UUID?
    var selectedVersionID: UUID?
}

enum PromptImportMode {
    case replace
    case merge
}

enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct PromptCategory: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

struct PromptVersion: Identifiable, Hashable, Codable {
    var id: UUID
    var promptID: UUID
    var parentID: UUID?
    var title: String
    var content: String
    var effectDescription: String
    var notes: String
    var branchName: String
    var createdAt: Date
    var depth: Int

    init(
        id: UUID = UUID(),
        promptID: UUID,
        parentID: UUID? = nil,
        title: String,
        content: String,
        effectDescription: String,
        notes: String = "",
        branchName: String,
        createdAt: Date = .now,
        depth: Int = 0
    ) {
        self.id = id
        self.promptID = promptID
        self.parentID = parentID
        self.title = title
        self.content = content
        self.effectDescription = effectDescription
        self.notes = notes
        self.branchName = branchName
        self.createdAt = createdAt
        self.depth = depth
    }
}

struct PromptDocument: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var categoryID: UUID
    var summary: String
    var versions: [PromptVersion]
    var currentVersionID: UUID
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryID: UUID,
        summary: String,
        versions: [PromptVersion],
        currentVersionID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.summary = summary
        self.versions = versions
        self.currentVersionID = currentVersionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var currentVersion: PromptVersion? {
        versions.first(where: { $0.id == currentVersionID })
    }
}

struct VersionGraphNode: Identifiable {
    var id: UUID { version.id }
    let version: PromptVersion
    let branchIndex: Int
    let level: Int
}

struct VersionGraphEdge: Identifiable {
    let id = UUID()
    let from: UUID
    let to: UUID
}

struct VersionGraphLayout {
    let nodes: [VersionGraphNode]
    let edges: [VersionGraphEdge]
}

@MainActor
final class PromptStore: ObservableObject {
    @Published var categories: [PromptCategory]
    @Published var prompts: [PromptDocument]
    @Published var selectedPromptID: UUID?
    @Published var selectedVersionID: UUID?
    @AppStorage("appThemeMode") var appThemeModeRawValue: String = AppThemeMode.system.rawValue

    private static let saveURL: URL = {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directoryURL = supportURL.appendingPathComponent("PromptManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("prompt-store.json")
    }()

    init(categories: [PromptCategory], prompts: [PromptDocument]) {
        self.categories = categories
        self.prompts = prompts.sorted { $0.updatedAt > $1.updatedAt }
        self.selectedPromptID = prompts.first?.id
        self.selectedVersionID = prompts.first?.currentVersionID
    }

    var selectedPromptIndex: Int? {
        prompts.firstIndex(where: { $0.id == selectedPromptID })
    }

    var selectedPrompt: PromptDocument? {
        guard let selectedPromptID else { return nil }
        return prompts.first(where: { $0.id == selectedPromptID })
    }

    var selectedVersion: PromptVersion? {
        guard let prompt = selectedPrompt else { return nil }
        let targetID = selectedVersionID ?? prompt.currentVersionID
        return prompt.versions.first(where: { $0.id == targetID })
    }

    var appThemeMode: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeModeRawValue) ?? .system }
        set { appThemeModeRawValue = newValue.rawValue }
    }

    func selectPrompt(_ promptID: UUID) {
        selectedPromptID = promptID
        if let prompt = prompts.first(where: { $0.id == promptID }) {
            selectedVersionID = prompt.currentVersionID
        }
    }

    func selectVersion(_ versionID: UUID) {
        selectedVersionID = versionID
    }

    func category(for categoryID: UUID) -> PromptCategory? {
        categories.first(where: { $0.id == categoryID })
    }

    func addCategory(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories.append(PromptCategory(name: trimmed, colorHex: colorHex))
        persist()
    }

    func updateCategory(id: UUID, name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let categoryIndex = categories.firstIndex(where: { $0.id == id }) else { return }

        categories[categoryIndex].name = trimmed
        categories[categoryIndex].colorHex = colorHex
        persist()
    }

    func deleteCategory(id: UUID) {
        guard categories.count > 1,
              !prompts.contains(where: { $0.categoryID == id }),
              let categoryIndex = categories.firstIndex(where: { $0.id == id }) else { return }

        categories.remove(at: categoryIndex)
        persist()
    }

    func updateSelectedPromptCategory(_ categoryID: UUID) {
        guard let promptIndex = selectedPromptIndex,
              categories.contains(where: { $0.id == categoryID }) else { return }

        prompts[promptIndex].categoryID = categoryID
        prompts[promptIndex].updatedAt = .now
        sortPrompts()
        persist()
    }

    func addPrompt(name: String, categoryID: UUID, summary: String, content: String = "", effectDescription: String = "") {
        let promptID = UUID()
        let initialVersion = PromptVersion(
            promptID: promptID,
            title: "v1 初稿",
            content: content,
            effectDescription: effectDescription,
            branchName: "main",
            depth: 0
        )

        let document = PromptDocument(
            id: promptID,
            name: name,
            categoryID: categoryID,
            summary: summary,
            versions: [initialVersion],
            currentVersionID: initialVersion.id,
            createdAt: .now,
            updatedAt: .now
        )

        prompts.insert(document, at: 0)
        selectedPromptID = document.id
        selectedVersionID = initialVersion.id
        persist()
    }

    func updateSelectedVersion(title: String, content: String, effectDescription: String, notes: String) {
        guard let promptIndex = selectedPromptIndex,
              let versionID = selectedVersionID,
              let versionIndex = prompts[promptIndex].versions.firstIndex(where: { $0.id == versionID }) else { return }

        prompts[promptIndex].versions[versionIndex].title = title
        prompts[promptIndex].versions[versionIndex].content = content
        prompts[promptIndex].versions[versionIndex].effectDescription = effectDescription
        prompts[promptIndex].versions[versionIndex].notes = notes
        prompts[promptIndex].updatedAt = .now
        sortPrompts()
        persist()
    }

    func renameSelectedBranch(to branchName: String) {
        let trimmed = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let promptIndex = selectedPromptIndex,
              let versionID = selectedVersionID,
              let version = prompts[promptIndex].versions.first(where: { $0.id == versionID }),
              !trimmed.isEmpty,
              trimmed != version.branchName else { return }

        let conflictingBranch = prompts[promptIndex].versions.contains {
            $0.branchName == trimmed && $0.branchName != version.branchName
        }
        guard !conflictingBranch else { return }

        for index in prompts[promptIndex].versions.indices {
            if prompts[promptIndex].versions[index].branchName == version.branchName {
                prompts[promptIndex].versions[index].branchName = trimmed
            }
        }

        prompts[promptIndex].updatedAt = .now
        sortPrompts()
        persist()
    }

    func updateSelectedPromptSummary(_ summary: String) {
        guard let promptIndex = selectedPromptIndex else { return }
        prompts[promptIndex].summary = summary
        prompts[promptIndex].updatedAt = .now
        sortPrompts()
        persist()
    }

    func evolveSelectedVersion() {
        guard let promptIndex = selectedPromptIndex,
              let current = selectedVersion else { return }

        let siblingCount = prompts[promptIndex].versions.filter { $0.branchName == current.branchName }.count
        let next = PromptVersion(
            promptID: prompts[promptIndex].id,
            parentID: current.id,
            title: "\(current.branchName) v\(siblingCount + 1)",
            content: current.content,
            effectDescription: current.effectDescription,
            notes: current.notes,
            branchName: current.branchName,
            depth: current.depth + 1
        )

        prompts[promptIndex].versions.append(next)
        prompts[promptIndex].currentVersionID = next.id
        prompts[promptIndex].updatedAt = .now
        selectedVersionID = next.id
        sortPrompts()
        persist()
    }

    func forkSelectedVersion() {
        guard let promptIndex = selectedPromptIndex,
              let current = selectedVersion else { return }

        let baseName = current.branchName == "main" ? "exp" : current.branchName
        let siblingBranches = Set(prompts[promptIndex].versions.map(\.branchName))
        var index = 1
        var candidate = "\(baseName)-\(index)"
        while siblingBranches.contains(candidate) {
            index += 1
            candidate = "\(baseName)-\(index)"
        }

        let fork = PromptVersion(
            promptID: prompts[promptIndex].id,
            parentID: current.id,
            title: "\(candidate) 分叉",
            content: current.content,
            effectDescription: current.effectDescription,
            notes: "从 \(current.title) 分叉",
            branchName: candidate,
            depth: current.depth + 1
        )

        prompts[promptIndex].versions.append(fork)
        prompts[promptIndex].currentVersionID = fork.id
        prompts[promptIndex].updatedAt = .now
        selectedVersionID = fork.id
        sortPrompts()
        persist()
    }

    func switchCurrentVersion(to versionID: UUID) {
        guard let promptIndex = selectedPromptIndex,
              prompts[promptIndex].versions.contains(where: { $0.id == versionID }) else { return }

        prompts[promptIndex].currentVersionID = versionID
        prompts[promptIndex].updatedAt = .now
        selectedVersionID = versionID
        sortPrompts()
        persist()
    }

    func deletePrompt(_ promptID: UUID) {
        guard let promptIndex = prompts.firstIndex(where: { $0.id == promptID }) else { return }

        let fallbackIndex = prompts.indices.contains(promptIndex + 1) ? promptIndex + 1 : promptIndex - 1
        prompts.remove(at: promptIndex)

        if prompts.indices.contains(fallbackIndex) {
            let fallbackPrompt = prompts[fallbackIndex]
            selectedPromptID = fallbackPrompt.id
            selectedVersionID = fallbackPrompt.currentVersionID
        } else {
            selectedPromptID = nil
            selectedVersionID = nil
        }

        persist()
    }

    func deleteSelectedVersion() {
        guard let promptIndex = selectedPromptIndex,
              let versionID = selectedVersionID,
              let versionIndex = prompts[promptIndex].versions.firstIndex(where: { $0.id == versionID }) else { return }

        let targetVersion = prompts[promptIndex].versions[versionIndex]
        let hasChildren = prompts[promptIndex].versions.contains(where: { $0.parentID == targetVersion.id })
        guard prompts[promptIndex].versions.count > 1, !hasChildren else { return }

        prompts[promptIndex].versions.remove(at: versionIndex)
        if prompts[promptIndex].currentVersionID == versionID {
            let fallbackVersion = prompts[promptIndex].versions.max(by: { $0.createdAt < $1.createdAt })
            prompts[promptIndex].currentVersionID = fallbackVersion?.id ?? prompts[promptIndex].versions[0].id
        }
        selectedVersionID = prompts[promptIndex].currentVersionID
        prompts[promptIndex].updatedAt = .now
        sortPrompts()
        persist()
    }

    func exportData(to url: URL) throws {
        let snapshot = PromptStoreSnapshot(
            categories: categories,
            prompts: prompts,
            selectedPromptID: selectedPromptID,
            selectedVersionID: selectedVersionID
        )
        let data = try JSONEncoder.promptStoreEncoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    func importData(from url: URL, mode: PromptImportMode) throws {
        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder.promptStoreDecoder.decode(PromptStoreSnapshot.self, from: data)
        applyImport(snapshot, mode: mode)
    }

    func versionLayout(for prompt: PromptDocument) -> VersionGraphLayout {
        let sorted = prompt.versions.sorted {
            if $0.depth == $1.depth { return $0.createdAt < $1.createdAt }
            return $0.depth < $1.depth
        }

        var branchOrder: [String] = []
        for version in sorted where !branchOrder.contains(version.branchName) {
            branchOrder.append(version.branchName)
        }

        let nodes = sorted.map {
            VersionGraphNode(
                version: $0,
                branchIndex: branchOrder.firstIndex(of: $0.branchName) ?? 0,
                level: $0.depth
            )
        }

        let edges = sorted.compactMap { version in
            version.parentID.map { VersionGraphEdge(from: $0, to: version.id) }
        }

        return VersionGraphLayout(nodes: nodes, edges: edges)
    }

    private func sortPrompts() {
        prompts.sort { $0.updatedAt > $1.updatedAt }
    }

    private func applyImport(_ snapshot: PromptStoreSnapshot, mode: PromptImportMode) {
        switch mode {
        case .replace:
            categories = snapshot.categories
            prompts = snapshot.prompts.sorted { $0.updatedAt > $1.updatedAt }
            selectedPromptID = snapshot.selectedPromptID ?? prompts.first?.id
            if let selectedPromptID,
               let prompt = prompts.first(where: { $0.id == selectedPromptID }) {
                selectedVersionID = snapshot.selectedVersionID ?? prompt.currentVersionID
            } else {
                selectedVersionID = prompts.first?.currentVersionID
            }

        case .merge:
            var mergedCategories = categories
            var importedCategoryIDMap: [UUID: UUID] = [:]

            for category in snapshot.categories {
                if let existingCategory = mergedCategories.first(where: { $0.id == category.id }) {
                    if let existingIndex = mergedCategories.firstIndex(where: { $0.id == existingCategory.id }) {
                        mergedCategories[existingIndex] = category
                    }
                    importedCategoryIDMap[category.id] = category.id
                    continue
                }

                if let sameNamedCategory = mergedCategories.first(where: {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .localizedCaseInsensitiveCompare(category.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                }) {
                    importedCategoryIDMap[category.id] = sameNamedCategory.id
                    continue
                }

                mergedCategories.append(category)
                importedCategoryIDMap[category.id] = category.id
            }

            categories = mergedCategories.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

            var promptMap = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
            for prompt in snapshot.prompts {
                var mergedPrompt = prompt
                if let mappedCategoryID = importedCategoryIDMap[prompt.categoryID] {
                    mergedPrompt.categoryID = mappedCategoryID
                }
                promptMap[prompt.id] = mergedPrompt
            }
            prompts = Array(promptMap.values).sorted { $0.updatedAt > $1.updatedAt }

            if let importedPromptID = snapshot.selectedPromptID,
               prompts.contains(where: { $0.id == importedPromptID }) {
                selectedPromptID = importedPromptID
                if let prompt = prompts.first(where: { $0.id == importedPromptID }) {
                    selectedVersionID = snapshot.selectedVersionID ?? prompt.currentVersionID
                }
            } else if let currentSelectedPromptID = selectedPromptID,
                      prompts.contains(where: { $0.id == currentSelectedPromptID }) {
                if let prompt = prompts.first(where: { $0.id == currentSelectedPromptID }) {
                    selectedVersionID = prompt.currentVersionID
                }
            } else {
                selectedPromptID = prompts.first?.id
                selectedVersionID = prompts.first?.currentVersionID
            }
        }

        persist()
    }

    private func persist() {
        let snapshot = PromptStoreSnapshot(
            categories: categories,
            prompts: prompts,
            selectedPromptID: selectedPromptID,
            selectedVersionID: selectedVersionID
        )

        do {
            let data = try JSONEncoder.promptStoreEncoder.encode(snapshot)
            try data.write(to: Self.saveURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist prompt store: \(error)")
        }
    }
}

extension PromptStore {
    static var sample: PromptStore {
        let categories = [
            PromptCategory(name: "对话", colorHex: "5B8CFF"),
            PromptCategory(name: "编程", colorHex: "7C5CFC"),
            PromptCategory(name: "分析", colorHex: "00A896")
        ]

        let promptID = UUID()
        let main1 = PromptVersion(
            id: UUID(),
            promptID: promptID,
            title: "v1 初稿",
            content: "你是一名资深产品顾问。先复述目标，再给出 3 个可落地方案，并说明每个方案的优缺点。",
            effectDescription: "输出结构清楚，适合做需求澄清和方案对比。",
            notes: "适合产品评审前使用。",
            branchName: "main",
            createdAt: .now.addingTimeInterval(-3600 * 30),
            depth: 0
        )
        let main2 = PromptVersion(
            id: UUID(),
            promptID: promptID,
            parentID: main1.id,
            title: "main v2",
            content: "你是一名资深产品顾问。先复述目标与约束，再给出 3 个可落地方案，并从成本、风险、上线速度做对比。",
            effectDescription: "相比初稿更偏决策支持，适合项目立项场景。",
            notes: "增加了约束识别。",
            branchName: "main",
            createdAt: .now.addingTimeInterval(-3600 * 18),
            depth: 1
        )
        let exp1 = PromptVersion(
            id: UUID(),
            promptID: promptID,
            parentID: main1.id,
            title: "exp-1 分叉",
            content: "你是一名严谨的策略顾问。先识别不确定性，再用表格给出方案、风险和验证动作。",
            effectDescription: "风险意识更强，适合复杂项目评估。",
            notes: "从初稿分叉到偏策略风格。",
            branchName: "exp-1",
            createdAt: .now.addingTimeInterval(-3600 * 22),
            depth: 1
        )
        let exp2 = PromptVersion(
            id: UUID(),
            promptID: promptID,
            parentID: exp1.id,
            title: "exp-1 v2",
            content: "你是一名严谨的策略顾问。先识别不确定性，再用表格给出方案、风险、验证动作，并标记推荐路径。",
            effectDescription: "更容易直接拿去开会讨论，推荐建议更明确。",
            notes: "补充推荐路径。",
            branchName: "exp-1",
            createdAt: .now.addingTimeInterval(-3600 * 12),
            depth: 2
        )

        let prompt = PromptDocument(
            id: promptID,
            name: "需求澄清顾问",
            categoryID: categories[0].id,
            summary: "用于把模糊需求转成可比选方案，并记录不同版本的效果变化。",
            versions: [main1, main2, exp1, exp2],
            currentVersionID: exp2.id,
            createdAt: .now.addingTimeInterval(-3600 * 30),
            updatedAt: .now.addingTimeInterval(-3600 * 12)
        )

        return PromptStore(categories: categories, prompts: [prompt])
    }

    static var persistedOrSample: PromptStore {
        guard let data = try? Data(contentsOf: saveURL),
              let snapshot = try? JSONDecoder.promptStoreDecoder.decode(PromptStoreSnapshot.self, from: data) else {
            let store = PromptStore.sample
            store.persist()
            return store
        }

        let store = PromptStore(categories: snapshot.categories, prompts: snapshot.prompts)
        store.selectedPromptID = snapshot.selectedPromptID ?? snapshot.prompts.first?.id
        if let selectedPromptID = store.selectedPromptID,
           let prompt = store.prompts.first(where: { $0.id == selectedPromptID }) {
            store.selectedVersionID = snapshot.selectedVersionID ?? prompt.currentVersionID
        } else {
            store.selectedVersionID = nil
        }
        return store
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

private extension JSONEncoder {
    static var promptStoreEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var promptStoreDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
