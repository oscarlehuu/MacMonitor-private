import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel

    var body: some View {
        Group {
            switch viewModel.screen {
            case .summary:
                summaryScreen
            case .settings:
                settingsScreen
            case .ramDetails:
                ramDetailsScreen
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    private var summaryScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ThermalCardView(
                state: viewModel.thermalState,
                lastUpdated: viewModel.snapshot?.timestamp,
                isStale: viewModel.isStale
            )

            if let snapshot = viewModel.snapshot {
                Button {
                    viewModel.showRAMDetails()
                } label: {
                    MetricCardView(
                        title: "RAM",
                        subtitle: "\(MetricFormatter.usage(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes))",
                        usagePercent: MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                        progress: snapshot.memory.usageRatio,
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)
                .help("Click to view top memory processes")

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

            summaryFooter
        }
    }

    private var settingsScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    viewModel.showSummary()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("Settings")
                    .font(.title3.weight(.semibold))
            }

            Divider()

            SettingsView(settings: viewModel.settings)

            Divider()

            HStack {
                Button("Back") {
                    viewModel.showSummary()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .font(.caption)
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

    private var ramDetailsScreen: some View {
        RAMDetailsView(
            viewModel: ramDetailsViewModel,
            memorySnapshot: viewModel.snapshot?.memory
        ) {
            viewModel.showSummary()
        }
    }

    private var summaryFooter: some View {
        HStack {
            Button("Refresh now") {
                viewModel.refreshNow()
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Settings") {
                viewModel.showSettings()
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
