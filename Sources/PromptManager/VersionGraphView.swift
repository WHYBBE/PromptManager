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
                                colors: [Color(light: Color(red: 0.67, green: 0.79, blue: 0.95), dark: Color(red: 0.35, green: 0.58, blue: 0.83)), Color(light: Color(red: 0.33, green: 0.61, blue: 0.91), dark: Color(red: 0.23, green: 0.44, blue: 0.74))],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color(light: Color(red: 0.57, green: 0.73, blue: 0.92).opacity(0.25), dark: Color.black.opacity(0.24)), radius: 6)
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
                context.stroke(path, with: .color(Color(light: Color(red: 0.83, green: 0.89, blue: 0.96), dark: Color(red: 0.24, green: 0.27, blue: 0.33))), lineWidth: 1)
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color(light: Color(red: 0.83, green: 0.89, blue: 0.96), dark: Color(red: 0.24, green: 0.27, blue: 0.33))), lineWidth: 1)
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
                            .fill(Color(light: Color(red: 0.16, green: 0.72, blue: 0.44), dark: Color(red: 0.24, green: 0.78, blue: 0.52)))
                            .frame(width: 10, height: 10)
                    }
                }
                Text(version.branchName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(light: Color(red: 0.20, green: 0.52, blue: 0.86), dark: Color(red: 0.51, green: 0.73, blue: 0.96)))
                Text(version.effectDescription)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(light: Color(red: 0.85, green: 0.92, blue: 1.0), dark: Color(red: 0.18, green: 0.29, blue: 0.42)) : Color(light: .white, dark: Color(red: 0.16, green: 0.18, blue: 0.22)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isCurrent ? Color(light: Color(red: 0.34, green: 0.62, blue: 0.92), dark: Color(red: 0.49, green: 0.71, blue: 0.95)) : Color(light: Color(red: 0.81, green: 0.88, blue: 0.95), dark: Color(red: 0.28, green: 0.32, blue: 0.38)), lineWidth: isCurrent ? 2 : 1)
                    )
            )
            .shadow(color: Color(light: Color(red: 0.77, green: 0.85, blue: 0.94).opacity(0.32), dark: Color.black.opacity(0.28)), radius: 12, y: 8)
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
