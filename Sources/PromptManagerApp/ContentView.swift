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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("提示词")
                .font(.title2.weight(.semibold))

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
    }
}

private struct PromptWorkspace: View {
    @EnvironmentObject private var store: PromptStore
    @State private var title = ""
    @State private var content = ""
    @State private var effect = ""
    @State private var notes = ""
    @State private var draftCategoryName = ""
    @State private var draftCategoryColor = "F97316"

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
                    Text(prompt.summary)
                        .foregroundStyle(.secondary)
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
                }
            }

            HStack(spacing: 12) {
                Label(version.branchName, systemImage: "point.3.connected.trianglepath.dotted")
                Label(version.title, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                Text(version.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
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

            FlowLayout(items: store.categories) { category in
                Label(category.name, systemImage: "tag.fill")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(category.color.opacity(0.18), in: Capsule())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func apply(version: PromptVersion) {
        title = version.title
        content = version.content
        effect = version.effectDescription
        notes = version.notes
    }
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
