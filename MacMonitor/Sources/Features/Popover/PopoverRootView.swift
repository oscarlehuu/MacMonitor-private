import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ThermalCardView(
                state: viewModel.thermalState,
                lastUpdated: viewModel.snapshot?.timestamp,
                isStale: viewModel.isStale
            )

            if let snapshot = viewModel.snapshot {
                MetricCardView(
                    title: "RAM",
                    subtitle: "\(MetricFormatter.usage(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes))",
                    usagePercent: MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                    progress: snapshot.memory.usageRatio,
                    tint: .blue
                )

                MetricCardView(
                    title: "Storage",
                    subtitle: "\(MetricFormatter.usage(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes))",
                    usagePercent: MetricFormatter.percent(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes),
                    progress: snapshot.storage.usageRatio,
                    tint: .mint
                )
            } else {
                Text("Collecting system metrics...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }

            Divider()

            footer
        }
        .padding(12)
        .frame(width: 360)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(settings: viewModel.settings)
                .frame(width: 380)
                .padding(16)
        }
    }

    private var header: some View {
        HStack {
            Text("MacMonitor")
                .font(.title3.weight(.semibold))

            Spacer()

            if viewModel.isStale {
                Label("Stale", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Refresh now") {
                viewModel.refreshNow()
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Settings") {
                viewModel.showingSettings = true
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .font(.caption)
    }
}

private struct MetricCardView: View {
    let title: String
    let subtitle: String
    let usagePercent: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(usagePercent)
                    .font(.subheadline.weight(.semibold))
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: min(max(progress, 0), 1))
                .tint(tint)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}
