import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PromptStore
    @State private var pendingImportURL: URL?
    @State private var importErrorMessage: String?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationSplitView {
            PromptSidebar(exportPrompt: exportPrompt)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } content: {
            PromptWorkspace(exportPrompt: exportPrompt)
                .navigationSplitViewColumnWidth(min: 420, ideal: 530)
        } detail: {
            VersionInspectorPanel()
                .navigationSplitViewColumnWidth(min: 420, ideal: 530)
        }
        .navigationSplitViewStyle(.balanced)
        .background(AppTheme.panelBackground)
        .navigationTitle(store.text(.appName))
        .sheet(isPresented: Binding(
            get: { store.isSettingsPresented },
            set: { store.isSettingsPresented = $0 }
        )) {
            SettingsView(
                exportAllData: exportAllData,
                chooseImportFile: chooseImportFile
            )
                .environmentObject(store)
                .frame(minWidth: 620, minHeight: 520)
        }
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

    private func exportPrompt(_ prompt: PromptDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultSelectedExportName(for: prompt.name)
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.exportPrompt(prompt.id, to: url)
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
        store.isSettingsPresented = false
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
}

private struct PromptSidebar: View {
    @EnvironmentObject private var store: PromptStore
    @State private var draggedPromptID: UUID?
    @State private var searchText = ""
    @AppStorage("sidebarSortMode") private var sortModeRawValue = PromptSortMode.custom.rawValue
    @AppStorage("sidebarIsGroupedByType") private var isGroupedByType = false
    let exportPrompt: (PromptDocument) -> Void

    private var sortMode: PromptSortMode {
        get { PromptSortMode(rawValue: sortModeRawValue) ?? .custom }
        nonmutating set { sortModeRawValue = newValue.rawValue }
    }

    private var canCustomizeOrder: Bool {
        sortMode == .custom && !isGroupedByType && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredPrompts: [PromptDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: [PromptDocument]
        if query.isEmpty {
            source = store.prompts
        } else {
            source = store.prompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(query)
                    || prompt.summary.localizedCaseInsensitiveContains(query)
                    || store.category(for: prompt.categoryID)?.name.localizedCaseInsensitiveContains(query) == true
                    || prompt.versions.contains { version in
                        version.title.localizedCaseInsensitiveContains(query)
                            || version.content.localizedCaseInsensitiveContains(query)
                            || version.effectDescription.localizedCaseInsensitiveContains(query)
                    }
            }
        }

        return sortedPrompts(source)
    }

    private var groupedPrompts: [PromptGroup] {
        store.categories.compactMap { category in
            let prompts = filteredPrompts.filter { $0.categoryID == category.id }
            return prompts.isEmpty ? nil : PromptGroup(category: category, prompts: prompts)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text(store.text(.appName))
                        .font(.title2.weight(.semibold))
                } icon: {
                    Image(systemName: "info.circle.text.page.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Button {
                    store.selectedPromptID = nil
                    store.selectedVersionID = nil
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.borderless)
                .help(store.text(.newPrompt))

                Button {
                    store.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.borderless)
                .help(store.text(.settings))
            }

            TextField(store.text(.searchPrompts), text: $searchText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Menu {
                    ForEach(PromptSortMode.allCases) { mode in
                        Button {
                            sortMode = mode
                        } label: {
                            Label(mode.title(in: store), systemImage: sortMode == mode ? "checkmark" : mode.symbolName)
                        }
                    }
                } label: {
                    Label(sortMode.title(in: store), systemImage: sortMode.symbolName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Toggle(isOn: $isGroupedByType) {
                    Text(store.text(.groupByType))
                }
                .toggleStyle(.checkbox)
            }

            ScrollView {
                if filteredPrompts.isEmpty {
                    ContentUnavailableView(store.text(.noPrompts), systemImage: "tray")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if isGroupedByType {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedPrompts) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.category.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                ForEach(group.prompts) { prompt in
                                    promptRow(prompt, index: nil)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                            promptRow(prompt, index: canCustomizeOrder ? index : nil)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                guard canCustomizeOrder else { return false }
                store.persistPromptOrder()
                draggedPromptID = nil
                return true
            }

        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private func promptRow(_ prompt: PromptDocument, index: Int?) -> some View {
        let canReorder = index != nil

        return VStack(alignment: .leading, spacing: 8) {
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(store.selectedPromptID == prompt.id ? AppTheme.selectionFill : AppTheme.inputFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(store.selectedPromptID == prompt.id ? Color.accentColor.opacity(0.45) : AppTheme.separator, lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.shadow, radius: 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            draggedPromptID = nil
            store.selectPrompt(prompt.id)
        }
        .opacity(draggedPromptID == prompt.id ? 0.92 : 1)
        .onDrag {
            guard canReorder else { return NSItemProvider() }
            draggedPromptID = prompt.id
            return NSItemProvider(object: prompt.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: PromptDropDelegate(
                targetPromptID: prompt.id,
                draggedPromptID: $draggedPromptID,
                store: store,
                canReorder: canReorder
            )
        )
        .contextMenu {
            Button(store.text(.exportSelected)) {
                exportPrompt(prompt)
            }

            Button(store.text(.moveUp)) {
                store.movePrompt(prompt.id, by: -1)
            }
            .disabled(index == nil || index == 0)

            Button(store.text(.moveDown)) {
                store.movePrompt(prompt.id, by: 1)
            }
            .disabled(index == nil || index == filteredPrompts.count - 1)

            Button(store.text(.deletePrompt), role: .destructive) {
                store.deletePrompt(prompt.id)
            }
        }
    }

    private func sortedPrompts(_ prompts: [PromptDocument]) -> [PromptDocument] {
        switch sortMode {
        case .custom:
            return prompts
        case .time:
            return prompts.sorted {
                if $0.updatedAt == $1.updatedAt { return $0.createdAt > $1.createdAt }
                return $0.updatedAt > $1.updatedAt
            }
        case .alphabetical:
            return prompts.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }
}

private enum PromptSortMode: String, CaseIterable, Identifiable {
    case time
    case custom
    case alphabetical

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .time: return "clock"
        case .custom: return "line.3.horizontal.decrease"
        case .alphabetical: return "textformat.abc"
        }
    }

    @MainActor func title(in store: PromptStore) -> String {
        switch self {
        case .time: return store.text(.sortByTime)
        case .custom: return store.text(.customSort)
        case .alphabetical: return store.text(.sortAlphabetically)
        }
    }
}

private struct PromptGroup: Identifiable {
    var id: UUID { category.id }
    let category: PromptCategory
    let prompts: [PromptDocument]
}

private struct PromptDropDelegate: DropDelegate {
    let targetPromptID: UUID
    @Binding var draggedPromptID: UUID?
    let store: PromptStore
    let canReorder: Bool

    func validateDrop(info: DropInfo) -> Bool {
        canReorder && info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard canReorder else { return }
        guard let draggedPromptID,
              draggedPromptID != targetPromptID else { return }

        store.previewMovePrompt(draggedPromptID, to: targetPromptID)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canReorder else { return false }
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
    let exportPrompt: (PromptDocument) -> Void
    @State private var summary = ""
    @State private var branchName = ""
    @State private var title = ""
    @State private var content = ""
    @State private var effect = ""
    @State private var notes = ""
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
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)
                .background(AppTheme.panelBackground)
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
                .scrollIndicators(.hidden)
                .background(AppTheme.panelBackground)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Text(prompt.name)
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Button(store.text(.evolve)) {
                        store.evolveSelectedVersion()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(store.text(.fork)) {
                        store.forkSelectedVersion()
                    }
                    .buttonStyle(.bordered)

                    Menu {
                        Button(store.text(.exportSelected)) {
                            exportPrompt(prompt)
                        }

                        Button(store.text(.deletePrompt), role: .destructive) {
                            store.deletePrompt(prompt.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help(store.text(.moreActions))
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                metadataPill(version.branchName, systemImage: "point.3.connected.trianglepath.dotted")
                metadataPill(version.title, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                metadataPill(version.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
            }

            Divider()

            HStack(alignment: .center, spacing: 12) {
                Text(store.text(.currentPromptType))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: Binding(
                    get: { prompt.categoryID },
                    set: { store.updateSelectedPromptCategory($0) }
                )) {
                    ForEach(store.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(store.text(.summary))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(store.text(.saveSummary)) {
                        store.updateSelectedPromptSummary(summary)
                    }
                    .buttonStyle(.bordered)
                }

                PlainMultilineTextView(text: $summary)
                    .padding(10)
                    .frame(minHeight: 120)
                    .background(AppTheme.inputCard)
            }
        }
        .padding(18)
        .background(AppTheme.panelCard)
    }

    private func metadataPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.05), in: Capsule())
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
        .padding(18)
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

}

private struct EditableCategory: Equatable {
    var name: String
    var colorHex: String
}

private struct SettingsView: View {
    @EnvironmentObject private var store: PromptStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftCategoryName = ""
    @State private var draftCategoryColor = "F97316"
    @State private var categoryDrafts: [UUID: EditableCategory] = [:]
    @State private var isClearDataConfirmationPresented = false
    let exportAllData: () -> Void
    let chooseImportFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(store.text(.settings))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(store.text(.cancel)) {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(store.text(.language))
                    .font(.headline)
                Picker(store.text(.language), selection: Binding(
                    get: { store.appLanguage },
                    set: { store.appLanguage = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Label(language.title, systemImage: language.symbolName)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(AppTheme.inputCard)

            VStack(alignment: .leading, spacing: 12) {
                Text(store.text(.theme))
                    .font(.headline)
                Picker(store.text(.theme), selection: Binding(
                    get: { store.appThemeMode },
                    set: { store.appThemeMode = $0 }
                )) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Label(mode.title(for: store.appLanguage), systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(AppTheme.inputCard)

            VStack(alignment: .leading, spacing: 12) {
                Text(store.text(.dataManagement))
                    .font(.headline)
                HStack {
                    Button(store.text(.export)) {
                        exportAllData()
                    }
                    .buttonStyle(.bordered)

                    Button(store.text(.importAction)) {
                        chooseImportFile()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(store.text(.clearData), role: .destructive) {
                        isClearDataConfirmationPresented = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(AppTheme.inputCard)

            Text(store.text(.customTypes))
                .font(.headline)

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
                .buttonStyle(.borderedProminent)
                .disabled(draftCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.categories) { category in
                        categoryRow(for: category)
                    }
                }
                .padding(.vertical, 2)
            }
            .appleScrollStyle()
        }
        .padding(24)
        .background(AppTheme.panelBackground)
        .onAppear {
            syncCategoryDrafts()
        }
        .onChange(of: store.categories) { _, _ in
            syncCategoryDrafts()
        }
        .confirmationDialog(
            store.text(.clearDataTitle),
            isPresented: $isClearDataConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(store.text(.clearDataConfirm), role: .destructive) {
                store.clearData()
                dismiss()
            }
            Button(store.text(.cancel), role: .cancel) {}
        } message: {
            Text(store.text(.clearDataMessage))
        }
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
        .background(AppTheme.inputCard)
    }

    private func syncCategoryDrafts() {
        var nextDrafts: [UUID: EditableCategory] = [:]
        for category in store.categories {
            nextDrafts[category.id] = categoryDrafts[category.id] ?? EditableCategory(name: category.name, colorHex: category.colorHex)
        }
        categoryDrafts = nextDrafts
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

            PlainMultilineTextView(text: $text)
                .padding(10)
                .frame(minHeight: minHeight)
                .background(
                    AppTheme.inputCard
                )
        }
    }
}

private struct PlainMultilineTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private struct AppleScrollStyle: NSViewRepresentable {
    let scrollerStyle: NSScroller.Style

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            tuneScrollViews(in: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            tuneScrollViews(in: nsView)
        }
    }

    private func tuneScrollViews(in view: NSView) {
        var current: NSView? = view
        while let parent = current?.superview {
            if let scrollView = parent as? NSScrollView {
                scrollView.scrollerStyle = scrollerStyle
                scrollView.autohidesScrollers = scrollerStyle == .overlay
                scrollView.drawsBackground = false
                scrollView.verticalScrollElasticity = .automatic
                scrollView.horizontalScrollElasticity = .automatic
                scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                return
            }
            current = parent
        }
    }
}

private extension View {
    func appleScrollStyle(_ scrollerStyle: NSScroller.Style = .overlay) -> some View {
        self
            .scrollIndicators(.automatic)
            .background(AppleScrollStyle(scrollerStyle: scrollerStyle))
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
            .appleScrollStyle()
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
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(store.selectedVersionID == version.id ? AppTheme.selectionFill : AppTheme.inputFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(store.selectedVersionID == version.id ? Color.accentColor.opacity(0.45) : AppTheme.separator, lineWidth: 1)
                                    )
                            )
                            .shadow(color: AppTheme.shadow, radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
            .appleScrollStyle()
        }
        .background(AppTheme.panelSurface)
    }
}

private enum AppTheme {
    static let panelBackground = Color(nsColor: .windowBackgroundColor)
    static let panelSurface = Color(nsColor: .controlBackgroundColor)
    static let inputFill = Color(nsColor: .textBackgroundColor)
    static let selectionFill = Color.accentColor.opacity(0.13)
    static let separator = Color(nsColor: .separatorColor).opacity(0.72)
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary.opacity(0.75)
    static let shadow = Color.black.opacity(0.08)

    static var panelCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(separator, lineWidth: 1)
            )
    }

    static var inputCard: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(inputFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(separator, lineWidth: 1)
            )
    }
}
