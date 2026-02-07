import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel

    @State private var simulatedThermalState: ThermalState?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(width: 480, height: 560)
        .background(PopoverTheme.bgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 40, y: 24)
        .onChange(of: viewModel.screen) { _, screen in
            if screen != .temperature {
                simulatedThermalState = nil
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 4) {
            navButton(
                symbol: "thermometer.medium",
                helpText: "Temperature",
                isActive: viewModel.screen == .temperature,
                action: viewModel.showTemperature
            )

            navButton(
                symbol: "memorychip",
                helpText: "RAM",
                isActive: viewModel.screen == .ram,
                action: viewModel.showRAM
            )

            navButton(
                symbol: "internaldrive",
                helpText: "Storage",
                isActive: viewModel.screen == .storage,
                action: viewModel.showStorage
            )

            Spacer(minLength: 0)

            navButton(
                symbol: "gearshape",
                helpText: "Settings",
                isActive: viewModel.screen == .settings || viewModel.screen == .ramPolicyManager,
                action: viewModel.showSettings
            )
        }
        .padding(.vertical, 12)
        .frame(width: 52)
        .background(PopoverTheme.bgPanel)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(width: 1)
        }
    }

    private func navButton(symbol: String, helpText: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? PopoverTheme.blue : PopoverTheme.textMuted)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? PopoverTheme.blueDim : Color.white.opacity(0.001))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isActive ? PopoverTheme.borderActive : .clear, lineWidth: 1)
                )
        }
        .frame(width: 44, height: 44)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: true) {
                Group {
                    switch viewModel.screen {
                    case .temperature:
                        temperatureScreen
                    case .ram:
                        ramScreen
                    case .storage:
                        storageScreen
                    case .settings:
                        settingsScreen
                    case .ramPolicyManager:
                        policiesScreen
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text(screenTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Spacer(minLength: 8)

            if viewModel.isStale {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                    Text("Stale")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(PopoverTheme.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(PopoverTheme.orangeDim)
                )
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var temperatureScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            thermalCard

            if let snapshot = viewModel.snapshot {
                HStack(spacing: 10) {
                    gaugeCard(
                        title: "RAM",
                        usageText: MetricFormatter.usage(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                        percentText: MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                        ratio: snapshot.memory.usageRatio,
                        color: PopoverTheme.blue,
                        action: viewModel.showRAM
                    )

                    gaugeCard(
                        title: "Storage",
                        usageText: MetricFormatter.usage(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes),
                        percentText: MetricFormatter.percent(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes),
                        ratio: snapshot.storage.usageRatio,
                        color: PopoverTheme.mint,
                        action: viewModel.showStorage
                    )
                }
            } else {
                collectingCard(text: "Collecting RAM and storage metrics...")
            }

            simulationCard
        }
    }

    private var thermalCard: some View {
        let state = displayedThermalState

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(thermalIndicatorFill(for: state))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: thermalSymbol(for: state))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(thermalColor(for: state))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(thermalColor(for: state))

                    Text(thermalDescription(for: state))
                        .font(.system(size: 11))
                        .foregroundStyle(PopoverTheme.textSecondary)

                    if let lastUpdated = viewModel.snapshot?.timestamp {
                        Text("Updated \(MetricFormatter.relativeTime(from: lastUpdated))")
                            .font(.system(size: 10))
                            .foregroundStyle(PopoverTheme.textMuted)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(thermalStrokeColor(for: state), lineWidth: 1)
        )
    }

    private func gaugeCard(
        title: String,
        usageText: String,
        percentText: String,
        ratio: Double,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(PopoverTheme.borderSubtle, lineWidth: 5)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: min(max(ratio, 0), 1))
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)

                    Text(percentText)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Text(usageText)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var simulationCard: some View {
        HStack(spacing: 6) {
            Text("Simulate:")
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            ForEach(simulatedStates, id: \.self) { state in
                Button {
                    simulatedThermalState = state
                } label: {
                    Text(state.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(displayedThermalState == state ? PopoverTheme.blue : PopoverTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(displayedThermalState == state ? PopoverTheme.blueDim : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(displayedThermalState == state ? PopoverTheme.blue : PopoverTheme.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var ramScreen: some View {
        RAMDetailsView(
            viewModel: ramDetailsViewModel,
            memorySnapshot: viewModel.snapshot?.memory,
            onBack: {},
            showsBackButton: false
        )
    }

    private var storageScreen: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 12) {
                    storageSummaryCard(snapshot.storage)
                }
            } else {
                collectingCard(text: "Collecting storage metrics...")
            }
        }
    }

    private func storageSummaryCard(_ storage: StorageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 16, weight: .medium))
                    Text("Storage")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PopoverTheme.mint)

                Spacer(minLength: 8)

                Text(MetricFormatter.percent(used: storage.usedBytes, total: storage.totalBytes))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.mint)
            }

            Text(MetricFormatter.usage(used: storage.usedBytes, total: storage.totalBytes))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text("\(MetricFormatter.bytes(max(storage.totalBytes - storage.usedBytes, 0))) available")
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PopoverTheme.borderSubtle)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PopoverTheme.mint, Color(hex: 0x14b8a6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(max(storage.usageRatio, 0), 1))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.mint.opacity(0.2), lineWidth: 1)
        )
    }

    private func collectingCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(PopoverTheme.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PopoverTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
    }

    private var settingsScreen: some View {
        SettingsView(
            settings: viewModel.settings,
            ramPolicyViewModel: ramPolicyViewModel,
            onOpenPolicyManager: viewModel.showRAMPolicyManager
        )
    }

    private var policiesScreen: some View {
        RAMPolicySettingsView(
            viewModel: ramPolicyViewModel,
            onBack: viewModel.showSettings
        )
    }

    private var footer: some View {
        HStack {
            Button {
                viewModel.refreshNow()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textMuted)

            Spacer(minLength: 0)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.red)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PopoverTheme.bgPanel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var screenTitle: String {
        switch viewModel.screen {
        case .temperature:
            return "Temperature"
        case .ram:
            return "RAM"
        case .storage:
            return "Storage"
        case .settings:
            return "Settings"
        case .ramPolicyManager:
            return "Policy Manager"
        }
    }

    private var displayedThermalState: ThermalState {
        simulatedThermalState ?? viewModel.thermalState
    }

    private var simulatedStates: [ThermalState] {
        [.nominal, .fair, .serious, .critical]
    }

    private func thermalDescription(for state: ThermalState) -> String {
        switch state {
        case .nominal:
            return "System thermal pressure is low."
        case .fair:
            return "Thermal pressure is elevated but stable."
        case .serious:
            return "System is under high thermal pressure."
        case .critical:
            return "Critical thermal pressure; performance may throttle."
        case .unknown:
            return "Thermal pressure data is unavailable."
        }
    }

    private func thermalColor(for state: ThermalState) -> Color {
        switch state {
        case .nominal:
            return PopoverTheme.green
        case .fair:
            return PopoverTheme.yellow
        case .serious:
            return PopoverTheme.orange
        case .critical:
            return PopoverTheme.red
        case .unknown:
            return PopoverTheme.textSecondary
        }
    }

    private func thermalStrokeColor(for state: ThermalState) -> Color {
        switch state {
        case .nominal:
            return PopoverTheme.green.opacity(0.25)
        case .fair:
            return PopoverTheme.yellow.opacity(0.25)
        case .serious:
            return PopoverTheme.orange.opacity(0.25)
        case .critical:
            return PopoverTheme.red.opacity(0.25)
        case .unknown:
            return PopoverTheme.borderSubtle
        }
    }

    private func thermalIndicatorFill(for state: ThermalState) -> Color {
        switch state {
        case .nominal:
            return PopoverTheme.greenDim
        case .fair:
            return PopoverTheme.yellowDim
        case .serious:
            return PopoverTheme.orangeDim
        case .critical:
            return PopoverTheme.redDim
        case .unknown:
            return Color.white.opacity(0.08)
        }
    }

    private func thermalSymbol(for state: ThermalState) -> String {
        switch state {
        case .nominal:
            return "thermometer.low"
        case .fair:
            return "thermometer.medium"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

enum PopoverTheme {
    static let bgDeep = Color(hex: 0x0a0c10)
    static let bgPanel = Color(hex: 0x111318)
    static let bgCard = Color(hex: 0x171a21)
    static let bgCardHover = Color(hex: 0x1c1f28)
    static let bgElevated = Color(hex: 0x1e2230)

    static let borderSubtle = Color.white.opacity(0.06)
    static let borderMedium = Color.white.opacity(0.10)
    static let borderActive = Color(hex: 0x3b82f6, opacity: 0.40)

    static let textPrimary = Color(hex: 0xe8eaed)
    static let textSecondary = Color(hex: 0x8b8fa3)
    static let textMuted = Color(hex: 0x5c6070)

    static let blue = Color(hex: 0x3b82f6)
    static let blueDim = Color(hex: 0x3b82f6, opacity: 0.08)
    static let blueGlow = Color(hex: 0x3b82f6, opacity: 0.15)

    static let green = Color(hex: 0x34d399)
    static let greenDim = Color(hex: 0x34d399, opacity: 0.12)

    static let yellow = Color(hex: 0xfbbf24)
    static let yellowDim = Color(hex: 0xfbbf24, opacity: 0.12)

    static let orange = Color(hex: 0xf97316)
    static let orangeDim = Color(hex: 0xf97316, opacity: 0.12)

    static let red = Color(hex: 0xef4444)
    static let redDim = Color(hex: 0xef4444, opacity: 0.12)

    static let mint = Color(hex: 0x2dd4bf)
    static let mintDim = Color(hex: 0x2dd4bf, opacity: 0.12)

    static let purple = Color(hex: 0xa78bfa)
    static let purpleDim = Color(hex: 0xa78bfa, opacity: 0.12)
}

struct PopoverToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isOn ? PopoverTheme.blue : Color.white.opacity(0.10))
                .frame(width: 36, height: 20)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 18 : 2)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
