import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PromptStore

    var body: some View {
        NavigationSplitView {
            PromptSidebar()
        } content: {
            PromptWorkspace()
        } detail: {
            VersionInspectorPanel()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct PromptSidebar: View {
    @EnvironmentObject private var store: PromptStore
    @State private var draftName = ""
    @State private var draftSummary = ""
    @State private var draftContent = ""
    @State private var draftEffect = ""
    @State private var selectedCategoryID: UUID?
    @State private var pendingImportURL: URL?
    @State private var importErrorMessage: String?
    @State private var exportErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack() {
                Text("提示词")
                    .font(.title2.weight(.semibold))
                Spacer()
                HStack {
                    Button("导出") {
                        exportAllData()
                    }
                    .buttonStyle(.bordered)

                    Button("导入") {
                        chooseImportFile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            List(selection: Binding(
                get: { store.selectedPromptID },
                set: { id in if let id { store.selectPrompt(id) } }
            )) {
                ForEach(store.prompts) { prompt in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(prompt.name)
                                .font(.headline)
                            Spacer()
                            if let category = store.category(for: prompt.categoryID) {
                                Text(category.name)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(category.color.opacity(0.16), in: Capsule())
                            }
                        }
                        Text(prompt.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    .tag(prompt.id)
                    .contextMenu {
                        Button("删除提示词", role: .destructive) {
                            store.deletePrompt(prompt.id)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("新建提示词")
                    .font(.headline)
                TextField("名称", text: $draftName)
                Picker("类型", selection: Binding(
                    get: { selectedCategoryID ?? store.categories.first?.id ?? UUID() },
                    set: { selectedCategoryID = $0 }
                )) {
                    ForEach(store.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                MultilineInput(title: "提示词内容", text: $draftContent, minHeight: 108)
                Button("创建") {
                    guard let categoryID = selectedCategoryID ?? store.categories.first?.id else { return }
                    store.addPrompt(
                        name: draftName,
                        categoryID: categoryID,
                        summary: draftSummary,
                        content: draftContent,
                        effectDescription: draftEffect
                    )
                    draftName = ""
                    draftSummary = ""
                    draftContent = ""
                    draftEffect = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            selectedCategoryID = store.categories.first?.id
        }
        .confirmationDialog(
            "导入数据",
            isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { if !$0 { pendingImportURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("覆盖当前数据", role: .destructive) {
                performImport(mode: .replace)
            }
            Button("合并到当前数据") {
                performImport(mode: .merge)
            }
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("导入文件后，你可以选择覆盖当前数据，或把导入内容合并到当前数据中。")
        }
        .alert(
            "导入失败",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
        .alert(
            "导出失败",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func exportAllData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "prompt-manager-export.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.exportData(to: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImportURL = url
    }

    private func performImport(mode: PromptImportMode) {
        guard let url = pendingImportURL else { return }
        do {
            try store.importData(from: url, mode: mode)
            pendingImportURL = nil
            selectedCategoryID = store.categories.first?.id
        } catch {
            pendingImportURL = nil
            importErrorMessage = error.localizedDescription
        }
    }
}

private struct PromptWorkspace: View {
    @EnvironmentObject private var store: PromptStore
    @State private var summary = ""
    @State private var title = ""
    @State private var content = ""
    @State private var effect = ""
    @State private var notes = ""
    @State private var draftCategoryName = ""
    @State private var draftCategoryColor = "F97316"
    @State private var categoryDrafts: [UUID: EditableCategory] = [:]

    var body: some View {
        Group {
            if let prompt = store.selectedPrompt, let version = store.selectedVersion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(prompt: prompt, version: version)
                        versionEditor(version: version)
                        categoryEditor
                    }
                    .padding(24)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    apply(version: version)
                }
                .onChange(of: store.selectedVersionID) { _, _ in
                    if let latest = store.selectedVersion {
                        apply(version: latest)
                    }
                }
            } else {
                ContentUnavailableView("没有选中提示词", systemImage: "text.badge.plus")
            }
        }
    }

    private func header(prompt: PromptDocument, version: PromptVersion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.name)
                        .font(.system(size: 30, weight: .bold))
                    MultilineInput(title: "用途描述", text: $summary, minHeight: 84)
                        .frame(maxWidth: 560)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button("演化") {
                        store.evolveSelectedVersion()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("分叉") {
                        store.forkSelectedVersion()
                    }
                    .buttonStyle(.bordered)

                    Button("删除提示词", role: .destructive) {
                        store.deletePrompt(prompt.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 12) {
                Label(version.branchName, systemImage: "point.3.connected.trianglepath.dotted")
                Label(version.title, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                Text(version.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            HStack {
                Spacer()
                Button("删除当前版本", role: .destructive) {
                    store.deleteSelectedVersion()
                }
                .buttonStyle(.bordered)

                Button("保存用途描述") {
                    store.updateSelectedPromptSummary(summary)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func versionEditor(version: PromptVersion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("版本内容")
                .font(.title3.weight(.semibold))

            TextField("版本标题", text: $title)
            MultilineInput(title: "提示词内容", text: $content, minHeight: 220)
            MultilineInput(title: "效果描述", text: $effect, minHeight: 100)
            MultilineInput(title: "备注", text: $notes, minHeight: 84)

            HStack {
                Button("保存当前版本") {
                    store.updateSelectedVersion(title: title, content: content, effectDescription: effect, notes: notes)
                }
                .buttonStyle(.borderedProminent)

                Button("切换为当前使用版本") {
                    store.switchCurrentVersion(to: version.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var categoryEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义类型")
                .font(.title3.weight(.semibold))

            if let prompt = store.selectedPrompt {
                Picker("当前提示词类型", selection: Binding(
                    get: { prompt.categoryID },
                    set: { store.updateSelectedPromptCategory($0) }
                )) {
                    ForEach(store.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                TextField("类型名称", text: $draftCategoryName)
                TextField("颜色 Hex", text: $draftCategoryColor)
                Button("添加类型") {
                    store.addCategory(name: draftCategoryName, colorHex: draftCategoryColor)
                    draftCategoryName = ""
                }
                .buttonStyle(.bordered)
                .disabled(draftCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.categories) { category in
                    categoryRow(for: category)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .onAppear {
            syncCategoryDrafts()
        }
        .onChange(of: store.categories) { _, _ in
            syncCategoryDrafts()
        }
    }

    private func apply(version: PromptVersion) {
        summary = store.selectedPrompt?.summary ?? ""
        title = version.title
        content = version.content
        effect = version.effectDescription
        notes = version.notes
    }

    private func categoryRow(for category: PromptCategory) -> some View {
        let draft = Binding(
            get: { categoryDrafts[category.id] ?? EditableCategory(name: category.name, colorHex: category.colorHex) },
            set: { categoryDrafts[category.id] = $0 }
        )

        let inUse = store.prompts.contains(where: { $0.categoryID == category.id })

        return HStack(spacing: 10) {
            Circle()
                .fill(category.color)
                .frame(width: 10, height: 10)

            TextField("类型名称", text: Binding(
                get: { draft.wrappedValue.name },
                set: { draft.wrappedValue.name = $0 }
            ))

            TextField("颜色 Hex", text: Binding(
                get: { draft.wrappedValue.colorHex },
                set: { draft.wrappedValue.colorHex = $0 }
            ))
            .frame(width: 110)

            Button("保存") {
                store.updateCategory(id: category.id, name: draft.wrappedValue.name, colorHex: draft.wrappedValue.colorHex)
            }
            .buttonStyle(.bordered)

            Button("删除", role: .destructive) {
                store.deleteCategory(id: category.id)
            }
            .buttonStyle(.bordered)
            .disabled(inUse || store.categories.count <= 1)

            if inUse {
                Text("使用中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 0.82, green: 0.88, blue: 0.95), lineWidth: 1)
                )
        )
    }

    private func syncCategoryDrafts() {
        var nextDrafts: [UUID: EditableCategory] = [:]
        for category in store.categories {
            nextDrafts[category.id] = categoryDrafts[category.id] ?? EditableCategory(name: category.name, colorHex: category.colorHex)
        }
        categoryDrafts = nextDrafts
    }
}

private struct EditableCategory: Equatable {
    var name: String
    var colorHex: String
}

private struct VersionInspectorPanel: View {
    @EnvironmentObject private var store: PromptStore

    var body: some View {
        Group {
            if let prompt = store.selectedPrompt {
                GeometryReader { proxy in
                    let availableHeight = max(proxy.size.height, 480)
                    let halfHeight = availableHeight / 2

                    VStack(spacing: 0) {
                        VersionHistoryPanel(prompt: prompt)
                            .frame(maxWidth: .infinity)
                            .frame(height: halfHeight)

                        Rectangle()
                            .fill(Color(red: 0.82, green: 0.88, blue: 0.95))
                            .frame(height: 1)

                        VersionGraphSection(prompt: prompt)
                            .frame(maxWidth: .infinity)
                            .frame(height: halfHeight)
                    }
                }
            } else {
                ContentUnavailableView("没有可视化数据", systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.96, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct MultilineInput: View {
    let title: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(red: 0.82, green: 0.88, blue: 0.95), lineWidth: 1)
                        )
                )
        }
    }
}

private struct VersionGraphSection: View {
    let prompt: PromptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("版本关系图")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView([.horizontal, .vertical]) {
                VersionGraphView(prompt: prompt)
                    .padding(5)
            }
        }
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }
}

private struct VersionHistoryPanel: View {
    @EnvironmentObject private var store: PromptStore
    let prompt: PromptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史版本")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(prompt.versions.sorted(by: { $0.createdAt > $1.createdAt })) { version in
                        Button {
                            store.selectVersion(version.id)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(version.title)
                                            .font(.headline)
                                        if prompt.currentVersionID == version.id {
                                            Text("当前使用")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(.green.opacity(0.18), in: Capsule())
                                        }
                                    }
                                    Text(version.effectDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(red: 0.35, green: 0.43, blue: 0.53))
                                        .lineLimit(2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(version.branchName)
                                    Text(version.createdAt.formatted(date: .numeric, time: .shortened))
                                        .foregroundStyle(Color(red: 0.45, green: 0.53, blue: 0.62))
                                }
                                .font(.caption)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(store.selectedVersionID == version.id ? Color(red: 0.84, green: 0.92, blue: 1.0) : .white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color(red: 0.80, green: 0.87, blue: 0.95), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color(red: 0.80, green: 0.87, blue: 0.95).opacity(0.32), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }
}
