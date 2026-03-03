import SwiftUI

private struct RingSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let thicknessRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let innerRadius = radius * max(0.2, min(thicknessRatio, 0.92))

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct StorageRingChartView: View {
    let buckets: [StorageRingBucket]
    let totalBytes: UInt64
    let onSelectBucketForDeletion: (StorageRingBucket) -> Void
    @State private var hoveredBucketID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                chart
                    .frame(width: 150, height: 150)

                legend
            }
        }
        .onChange(of: buckets.map(\.id)) { _, ids in
            if let hoveredBucketID, !ids.contains(hoveredBucketID) {
                self.hoveredBucketID = nil
            }
        }
    }

    private var chart: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let frame = CGRect(x: 0, y: 0, width: size, height: size)

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.element.bucket.id) { _, segment in
                    let isHovered = hoveredBucketID == segment.bucket.id
                    let isDimmed = hoveredBucketID != nil && !isHovered
                    RingSliceShape(
                        startAngle: segment.startAngle,
                        endAngle: segment.endAngle,
                        thicknessRatio: 0.62
                    )
                    .fill(color(for: segment.bucket))
                    .opacity(isDimmed ? 0.35 : 1.0)
                    .overlay(
                        RingSliceShape(
                            startAngle: segment.startAngle,
                            endAngle: segment.endAngle,
                            thicknessRatio: 0.62
                        )
                        .stroke(isHovered ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
                    )
                    .contextMenu {
                        Button("Select for Deletion") {
                            onSelectBucketForDeletion(segment.bucket)
                        }
                    }
                }

                VStack(spacing: 2) {
                    if let hoveredBucket {
                        Text(hoveredBucket.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(MetricFormatter.bytes(hoveredBucket.sizeBytes))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Scanned")
                            .font(.system(size: 9))
                            .foregroundStyle(PopoverTheme.textMuted)
                        Text(MetricFormatter.bytes(totalBytes))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: size * 0.48)
            }
            .frame(width: frame.width, height: frame.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredBucketID = hoveredBucketID(at: location, chartSize: size)
                case .ended:
                    hoveredBucketID = nil
                }
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(legendBuckets) { bucket in
                let isHovered = hoveredBucketID == bucket.id
                let isDimmed = hoveredBucketID != nil && !isHovered
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(for: bucket))
                        .frame(width: 7, height: 7)

                    Text(bucket.label)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(MetricFormatter.bytes(bucket.sizeBytes))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .opacity(isDimmed ? 0.35 : 1.0)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isHovered ? PopoverTheme.bgElevated : Color.clear)
                )
                .onHover { isHovering in
                    if isHovering {
                        hoveredBucketID = bucket.id
                    } else if hoveredBucketID == bucket.id {
                        hoveredBucketID = nil
                    }
                }
                .contextMenu {
                    Button("Select for Deletion") {
                        onSelectBucketForDeletion(bucket)
                    }
                }
            }

            if remainingBucketCount > 0 {
                Text("+\(remainingBucketCount) more")
                    .font(.system(size: 9))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .opacity(hoveredBucketID == nil ? 1.0 : 0.55)
            }
        }
    }

    private var hoveredBucket: StorageRingBucket? {
        guard let hoveredBucketID else { return nil }
        return buckets.first(where: { $0.id == hoveredBucketID })
    }

    private var legendBuckets: [StorageRingBucket] {
        guard buckets.count > 6 else { return buckets }

        guard let otherBucket = buckets.first(where: { $0.id == "other" }) else {
            return Array(buckets.prefix(6))
        }

        var selected = Array(buckets.prefix(5))
        if !selected.contains(where: { $0.id == otherBucket.id }) {
            selected.append(otherBucket)
        }

        if selected.count < 6 {
            for bucket in buckets where !selected.contains(where: { $0.id == bucket.id }) {
                selected.append(bucket)
                if selected.count == 6 {
                    break
                }
            }
        }

        return selected
    }

    private var remainingBucketCount: Int {
        max(0, buckets.count - legendBuckets.count)
    }

    private var segments: [(bucket: StorageRingBucket, startAngle: Angle, endAngle: Angle)] {
        let sum = buckets.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        guard sum > 0 else { return [] }

        let activeBuckets = buckets.filter { $0.sizeBytes > 0 }
        var spans = activeBuckets.map { bucket -> Double in
            let fraction = Double(bucket.sizeBytes) / Double(sum)
            return max(2.0, fraction * 360.0)
        }

        let total = spans.reduce(0.0, +)
        if total > 360.0 {
            let scale = 360.0 / total
            spans = spans.map { $0 * scale }
        }

        var startDegrees = -90.0
        var output: [(bucket: StorageRingBucket, startAngle: Angle, endAngle: Angle)] = []
        output.reserveCapacity(activeBuckets.count)

        for (bucket, span) in zip(activeBuckets, spans) {
            let endDegrees = startDegrees + span
            output.append(
                (
                    bucket: bucket,
                    startAngle: .degrees(startDegrees),
                    endAngle: .degrees(endDegrees)
                )
            )
            startDegrees = endDegrees
        }

        return output
    }

    private func color(for bucket: StorageRingBucket) -> Color {
        if bucket.id == "other" {
            return PopoverTheme.textMuted
        }

        let hash = stableHash(for: bucket.id)
        let hue = Double(hash % 360) / 360.0
        let saturation = 0.68 + (Double((hash >> 8) % 16) / 100.0)
        let brightness = 0.84 + (Double((hash >> 16) % 12) / 100.0)
        return Color(
            hue: hue,
            saturation: min(saturation, 0.9),
            brightness: min(brightness, 0.96)
        )
    }

    private func stableHash(for value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func hoveredBucketID(at location: CGPoint, chartSize: CGFloat) -> String? {
        guard chartSize > 0 else { return nil }

        let center = CGPoint(x: chartSize * 0.5, y: chartSize * 0.5)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = chartSize * 0.5
        let innerRadius = outerRadius * 0.62

        guard distance >= innerRadius, distance <= outerRadius else { return nil }

        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < -90 {
            degrees += 360
        }

        for segment in segments {
            let start = segment.startAngle.degrees
            let end = segment.endAngle.degrees
            if degrees >= start && degrees < end {
                return segment.bucket.id
            }
        }

        if let lastSegment = segments.last,
           abs(degrees - lastSegment.endAngle.degrees) < 0.000_1 {
            return lastSegment.bucket.id
        }

        return nil
    }
}
