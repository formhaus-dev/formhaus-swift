@_spi(Renderer) import FormhausCore
import SwiftUI

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let limit = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .infinity
        let rows = arrange(limit, subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: limit.isFinite ? limit : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: row.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let ideal = subviews[index].sizeThatFits(.unspecified)
            let width = min(ideal.width, maxWidth)
            let size = width < ideal.width ? subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)) : ideal
            if !row.indices.isEmpty, row.width + spacing + width > maxWidth {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            row.sizes.append(CGSize(width: width, height: size.height))
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

struct ColumnGrid: Layout {
    let columns: Int?
    let minimumWidth: CGFloat
    let compactWidth: CGFloat
    let spacing: CGFloat
    var fraction: CGFloat = 0.7
    var balanced = false

    func columnCount(_ width: CGFloat, _ count: Int) -> Int {
        let fitted = clampedInt((width + spacing) / max(1, minimumWidth + spacing), 1...12) ?? 1
        let chosen = columns ?? fitted
        let limited = width < compactWidth && columns != 1 ? min(chosen, 2) : chosen
        var result = max(1, min(limited, max(1, count)))
        while result > 1, cellWidth(width, result) < minimumWidth * fraction { result -= 1 }
        while balanced, result > 2, result < count, count % result != 0, count % result * 2 < result { result -= 1 }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? minimumWidth * 2
        let heights = rowHeights(width, subviews)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let count = columnCount(bounds.width, subviews.count)
        let cell = cellWidth(bounds.width, count)
        let heights = rowHeights(bounds.width, subviews)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<count {
                let index = row * count + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (cell + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: cell, height: height))
            }
            y += height + spacing
        }
    }

    private func cellWidth(_ width: CGFloat, _ count: Int) -> CGFloat {
        max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
    }

    private func rowHeights(_ width: CGFloat, _ subviews: Subviews) -> [CGFloat] {
        let count = columnCount(width, subviews.count)
        let cell = cellWidth(width, count)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            subviews[start..<min(start + count, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max() ?? 0
        }
    }
}
