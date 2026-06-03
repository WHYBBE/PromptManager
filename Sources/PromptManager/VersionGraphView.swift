import AppKit
import SwiftUI

struct VersionGraphView: View {
    @EnvironmentObject private var store: PromptStore
    let prompt: PromptDocument

    private let horizontalSpacing: CGFloat = 190
    private let verticalSpacing: CGFloat = 140
    private let nodeSize = CGSize(width: 160, height: 76)

    var body: some View {
        let layout = store.versionLayout(for: prompt)
        let positions = Dictionary(uniqueKeysWithValues: layout.nodes.map { node in
            (node.id, CGPoint(
                x: CGFloat(node.level) * horizontalSpacing + 120,
                y: CGFloat(node.branchIndex) * verticalSpacing + 120
            ))
        })

        ZStack(alignment: .topLeading) {
            gridBackground

            ForEach(layout.edges) { edge in
                if let from = positions[edge.from], let to = positions[edge.to] {
                    SmoothEdge(from: from, to: to)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.45), Color.accentColor.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                }
            }

            ForEach(layout.nodes) { node in
                if let position = positions[node.id] {
                    VersionNodeCard(
                        version: node.version,
                        isCurrent: prompt.currentVersionID == node.version.id,
                        isSelected: store.selectedVersionID == node.version.id,
                        position: position,
                        size: nodeSize
                    )
                }
            }
        }
        .frame(
            width: CGFloat((layout.nodes.map(\.level).max() ?? 0) + 1) * horizontalSpacing + 220,
            height: CGFloat((layout.nodes.map(\.branchIndex).max() ?? 0) + 1) * verticalSpacing + 220,
            alignment: .topLeading
        )
    }

    private var gridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 36
            for x in stride(from: 0, through: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color(nsColor: .separatorColor).opacity(0.22)), lineWidth: 1)
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color(nsColor: .separatorColor).opacity(0.22)), lineWidth: 1)
            }
        }
    }
}

private struct GraphNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

private struct VersionNodeCard: View {
    @EnvironmentObject private var store: PromptStore
    let version: PromptVersion
    let isCurrent: Bool
    let isSelected: Bool
    let position: CGPoint
    let size: CGSize

    var body: some View {
        Button(action: handleClick) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(version.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Spacer()
                    if isCurrent {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(version.branchName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Text(version.effectDescription)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isCurrent ? Color.accentColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.72), lineWidth: isCurrent ? 1.5 : 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(GraphNodeButtonStyle())
        .position(position)
    }

    private func handleClick() {
        if NSApp.currentEvent?.clickCount == 2 {
            store.switchCurrentVersion(to: version.id)
        } else {
            store.selectVersion(version.id)
        }
    }
}

private struct SmoothEdge: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)

        let midX = (from.x + to.x) / 2
        let dx = max((to.x - from.x) * 0.36, 50)
        let control1 = CGPoint(x: min(midX, from.x + dx), y: from.y)
        let control2 = CGPoint(x: max(midX, to.x - dx), y: to.y)
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }
}

struct FlowLayout<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(minHeight: 40)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                content(item)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item.id == items.last?.id {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == items.last?.id {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
}
