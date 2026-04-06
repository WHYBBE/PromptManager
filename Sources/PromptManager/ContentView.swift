import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
        .background(AppTheme.panelBackground)
        .navigationTitle(store.text(.appName))
    }
}

private struct PromptSidebar: View {
    @EnvironmentObject private var store: PromptStore
    @State private var pendingImportURL: URL?
    @State private var importErrorMessage: String?
    @State private var exportErrorMessage: String?
    @State private var draggedPromptID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(store.text(.appName))
                    .font(.title2.weight(.semibold))
            } icon: {
                Image(systemName: "info.circle.text.page.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            HStack() {
                Menu {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            store.appLanguage = language
                        } label: {
                            Label(language.title, systemImage: language.symbolName)
                        }
                    }
                } label: {
                    Label(store.text(.language), systemImage: store.appLanguage.symbolName)
                }
                .fixedSize()
                .menuStyle(.borderlessButton)
                
                Spacer()

                Menu {
                    ForEach(AppThemeMode.allCases) { mode in
                        Button {
                            store.appThemeMode = mode
                        } label: {
                            Label(mode.title(for: store.appLanguage), systemImage: mode.symbolName)
                        }
                    }
                } label: {
                    Label(store.text(.theme), systemImage: store.appThemeMode.symbolName)
                }
                .fixedSize()
                .menuStyle(.borderlessButton)
            }

            HStack {
                Button(store.text(.export)) {
                    exportAllData()
                }
                .buttonStyle(.bordered)

                Button(store.text(.exportSelected)) {
                    exportSelectedPrompt()
                }
                .buttonStyle(.bordered)
                .disabled(store.selectedPrompt == nil)

                Button(store.text(.importAction)) {
                    chooseImportFile()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()

                Button(store.text(.newPrompt)) {
                    store.selectedPromptID = nil
                    store.selectedVersionID = nil
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(store.prompts.enumerated()), id: \.element.id) { index, prompt in
                        promptRow(prompt, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                store.persistPromptOrder()
                draggedPromptID = nil
                return true
            }

        }
        .padding(20)
        .confirmationDialog(
            store.text(.importDataTitle),
            isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { if !$0 { pendingImportURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(store.text(.replaceData), role: .destructive) {
                performImport(mode: .replace)
            }
            Button(store.text(.mergeData)) {
                performImport(mode: .merge)
            }
            Button(store.text(.cancel), role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text(store.text(.importDataMessage))
        }
        .alert(
            store.text(.importFailed),
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button(store.text(.ok), role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
        .alert(
            store.text(.exportFailed),
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button(store.text(.ok), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func exportAllData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = store.appLanguage == .english ? "Prompt Manager Export.json" : "Prompt Manager 导出.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.exportData(to: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportSelectedPrompt() {
        guard let selectedPrompt = store.selectedPrompt else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultSelectedExportName(for: selectedPrompt.name)
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.exportSelectedPrompt(to: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func defaultSelectedExportName(for promptName: String) -> String {
        let sanitizedName = promptName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let fallbackName = store.appLanguage == .english ? "Selected Prompt" : "当前提示词"
        let baseName = sanitizedName.isEmpty ? fallbackName : sanitizedName
        return "\(baseName).json"
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
        } catch {
            pendingImportURL = nil
            importErrorMessage = error.localizedDescription
        }
    }

    private func promptRow(_ prompt: PromptDocument, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(prompt.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(prompt.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let category = store.category(for: prompt.categoryID) {
                    Text(category.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.color.opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(store.selectedPromptID == prompt.id ? AppTheme.selectionFill : AppTheme.inputFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.separator, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadow, radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            draggedPromptID = nil
            store.selectPrompt(prompt.id)
        }
        .opacity(draggedPromptID == prompt.id ? 0.92 : 1)
        .onDrag {
            draggedPromptID = prompt.id
            return NSItemProvider(object: prompt.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: PromptDropDelegate(
                targetPromptID: prompt.id,
                draggedPromptID: $draggedPromptID,
                store: store
            )
        )
        .contextMenu {
            Button(store.text(.moveUp)) {
                store.movePrompt(prompt.id, by: -1)
            }
            .disabled(index == 0)

            Button(store.text(.moveDown)) {
                store.movePrompt(prompt.id, by: 1)
            }
            .disabled(index == store.prompts.count - 1)

            Button(store.text(.deletePrompt), role: .destructive) {
                store.deletePrompt(prompt.id)
            }
        }
    }
}

private struct PromptDropDelegate: DropDelegate {
    let targetPromptID: UUID
    @Binding var draggedPromptID: UUID?
    let store: PromptStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard let draggedPromptID,
              draggedPromptID != targetPromptID else { return }

        store.previewMovePrompt(draggedPromptID, to: targetPromptID)
    }

    func performDrop(info: DropInfo) -> Bool {
        store.persistPromptOrder()
        draggedPromptID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {}
}

private struct PromptWorkspace: View {
    @EnvironmentObject private var store: PromptStore
    @State private var summary = ""
    @State private var branchName = ""
    @State private var title = ""
    @State private var content = ""
    @State private var effect = ""
    @State private var notes = ""
    @State private var draftCategoryName = ""
    @State private var draftCategoryColor = "F97316"
    @State private var categoryDrafts: [UUID: EditableCategory] = [:]
    @State private var newPromptName = ""
    @State private var newPromptSummary = ""
    @State private var newPromptCategoryID: UUID?

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
                ScrollView {
                    newPromptPanel
                        .padding(24)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .onAppear {
            newPromptCategoryID = store.categories.first?.id
        }
        .onChange(of: store.categories) { _, categories in
            if let selected = newPromptCategoryID, categories.contains(where: { $0.id == selected }) {
                return
            }
            newPromptCategoryID = categories.first?.id
        }
    }

    private func header(prompt: PromptDocument, version: PromptVersion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack() {
                        Text(prompt.name)
                            .font(.system(size: 30, weight: .bold))
                        Spacer()
                        HStack(spacing: 10) {
                            Button(store.text(.evolve)) {
                                store.evolveSelectedVersion()
                            }
                            .buttonStyle(.borderedProminent)

                            Button(store.text(.fork)) {
                                store.forkSelectedVersion()
                            }
                            .buttonStyle(.bordered)

                            Button(store.text(.deletePrompt), role: .destructive) {
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
                    
                    MultilineInput(title: store.text(.summary), text: $summary, minHeight: 84)
                        .frame(maxWidth: 560)
                    
                    Button(store.text(.saveSummary)) {
                        store.updateSelectedPromptSummary(summary)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                
            }
        }
    }

    private func versionEditor(version: PromptVersion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.text(.versionContent))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(store.text(.saveCurrentVersion)) {
                    store.renameSelectedBranch(to: branchName)
                    store.updateSelectedVersion(title: title, content: content, effectDescription: effect, notes: notes)
                }
                .buttonStyle(.borderedProminent)

                Button(store.text(.switchCurrentVersion)) {
                    store.switchCurrentVersion(to: version.id)
                }
                .buttonStyle(.bordered)

                Button(store.text(.deleteCurrentVersion), role: .destructive) {
                    store.deleteSelectedVersion()
                }
                .buttonStyle(.bordered)
            }

            HStack(alignment: .top, spacing: 12) {
                compactLabeledField(title: store.text(.branchName), text: $branchName)
                    .frame(maxWidth: 220)
                compactLabeledField(title: store.text(.versionTitle), text: $title)
            }

            MultilineInput(title: store.text(.promptContent), text: $content, minHeight: 220)
            MultilineInput(title: store.text(.effectDescription), text: $effect, minHeight: 100)
            MultilineInput(title: store.text(.notes), text: $notes, minHeight: 84)
        }
        .padding(20)
        .background(
            AppTheme.panelCard
        )
    }

    private func compactLabeledField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var categoryEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.text(.customTypes))
                .font(.title3.weight(.semibold))

            if let prompt = store.selectedPrompt {
                Picker(store.text(.currentPromptType), selection: Binding(
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
                TextField(store.text(.typeName), text: $draftCategoryName)
                ColorPicker(
                    store.text(.color),
                    selection: Binding(
                        get: { Color(hex: draftCategoryColor) },
                        set: { draftCategoryColor = $0.hexString ?? draftCategoryColor }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                Button(store.text(.addType)) {
                    store.addCategory(name: draftCategoryName, colorHex: draftCategoryColor)
                    draftCategoryName = ""
                    draftCategoryColor = "F97316"
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
            AppTheme.panelCard
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
        branchName = version.branchName
        title = version.title
        content = version.content
        effect = version.effectDescription
        notes = version.notes
    }

    private var newPromptPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.text(.createPromptTitle))
                    .font(.system(size: 30, weight: .bold))
                Text(store.text(.createPromptHint))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                TextField(store.text(.name), text: $newPromptName)

                Picker(store.text(.type), selection: Binding(
                    get: { newPromptCategoryID ?? store.categories.first?.id ?? UUID() },
                    set: { newPromptCategoryID = $0 }
                )) {
                    ForEach(store.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }

                MultilineInput(title: store.text(.summary), text: $newPromptSummary, minHeight: 120)

                HStack {
                    Spacer()
                    Button(store.text(.createPromptAction)) {
                        createPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPromptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .background(AppTheme.panelCard)
        }
    }

    private func createPrompt() {
        guard let categoryID = newPromptCategoryID ?? store.categories.first?.id else { return }
        store.addPrompt(
            name: newPromptName,
            categoryID: categoryID,
            summary: newPromptSummary
        )
        newPromptName = ""
        newPromptSummary = ""
        newPromptCategoryID = store.categories.first?.id
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

            TextField(store.text(.typeName), text: Binding(
                get: { draft.wrappedValue.name },
                set: { draft.wrappedValue.name = $0 }
            ))

            ColorPicker(
                store.text(.color),
                selection: Binding(
                    get: { Color(hex: draft.wrappedValue.colorHex) },
                    set: { color in
                        if let hex = color.hexString {
                            draft.wrappedValue.colorHex = hex
                        }
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()

            Button(store.text(.save)) {
                store.updateCategory(id: category.id, name: draft.wrappedValue.name, colorHex: draft.wrappedValue.colorHex)
            }
            .buttonStyle(.bordered)

            Button(store.text(.delete), role: .destructive) {
                store.deleteCategory(id: category.id)
            }
            .buttonStyle(.bordered)
            .disabled(inUse || store.categories.count <= 1)

            if inUse {
                Text(store.text(.inUse))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            AppTheme.inputCard
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
                            .fill(AppTheme.separator)
                            .frame(height: 1)

                        VersionGraphSection(prompt: prompt)
                            .frame(maxWidth: .infinity)
                            .frame(height: halfHeight)
                    }
                }
            } else {
                ContentUnavailableView(store.text(.noVisualizationData), systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
        }
        .background(
            AppTheme.panelBackground
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
                    AppTheme.inputCard
                )
        }
    }
}

private struct VersionGraphSection: View {
    @EnvironmentObject private var store: PromptStore
    let prompt: PromptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.text(.versionGraph))
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView([.horizontal, .vertical]) {
                VersionGraphView(prompt: prompt)
                    .padding(5)
            }
        }
        .background(AppTheme.panelSurface)
    }
}

private struct VersionHistoryPanel: View {
    @EnvironmentObject private var store: PromptStore
    let prompt: PromptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.text(.historyVersions))
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(prompt.versions.sorted(by: { $0.createdAt > $1.createdAt })) { version in
                        Button {
                            if NSApp.currentEvent?.clickCount == 2 {
                                store.switchCurrentVersion(to: version.id)
                            } else {
                                store.selectVersion(version.id)
                            }
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(version.title)
                                            .font(.headline)
                                        if prompt.currentVersionID == version.id {
                                            Text(store.text(.currentInUse))
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(.green.opacity(0.18), in: Capsule())
                                        }
                                    }
                                    Text(version.effectDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .lineLimit(2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(version.branchName)
                                    Text(version.createdAt.formatted(date: .numeric, time: .shortened))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }
                                .font(.caption)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(store.selectedVersionID == version.id ? AppTheme.selectionFill : AppTheme.inputFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(AppTheme.separator, lineWidth: 1)
                                    )
                            )
                            .shadow(color: AppTheme.shadow, radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.panelSurface)
    }
}

private enum AppTheme {
    static let panelBackground = LinearGradient(
        colors: [
            Color(light: Color(red: 0.97, green: 0.98, blue: 1.0), dark: Color(red: 0.10, green: 0.11, blue: 0.13)),
            Color(light: Color(red: 0.92, green: 0.96, blue: 1.0), dark: Color(red: 0.12, green: 0.14, blue: 0.18))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelSurface = Color(light: Color(red: 0.95, green: 0.97, blue: 1.0), dark: Color(red: 0.13, green: 0.15, blue: 0.19))
    static let inputFill = Color(light: .white, dark: Color(red: 0.16, green: 0.18, blue: 0.22))
    static let selectionFill = Color(light: Color(red: 0.84, green: 0.92, blue: 1.0), dark: Color(red: 0.18, green: 0.29, blue: 0.42))
    static let separator = Color(light: Color(red: 0.82, green: 0.88, blue: 0.95), dark: Color(red: 0.28, green: 0.32, blue: 0.38))
    static let secondaryText = Color(light: Color(red: 0.35, green: 0.43, blue: 0.53), dark: Color(red: 0.72, green: 0.76, blue: 0.82))
    static let tertiaryText = Color(light: Color(red: 0.45, green: 0.53, blue: 0.62), dark: Color(red: 0.58, green: 0.63, blue: 0.70))
    static let shadow = Color(light: Color(red: 0.80, green: 0.87, blue: 0.95).opacity(0.32), dark: Color.black.opacity(0.28))

    static var panelCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(separator.opacity(0.65), lineWidth: 1)
            )
    }

    static var inputCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(inputFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(separator, lineWidth: 1)
            )
    }
}
