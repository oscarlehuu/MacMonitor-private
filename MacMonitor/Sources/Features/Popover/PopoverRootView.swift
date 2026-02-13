import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController

    @State private var simulatedThermalState: ThermalState?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(width: 480, height: 560)
        .background(PopoverTheme.bgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 16)
        .preferredColorScheme(settings.appTheme.isDark ? .dark : .light)
        .id(settings.appTheme)
        .onChange(of: viewModel.screen) { _, screen in
            if screen != .temperature {
                simulatedThermalState = nil
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 2) {
            navButton(
                symbol: "battery.100",
                helpText: "Battery",
                isActive: viewModel.screen == .battery,
                action: viewModel.showBattery
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
                isActive: viewModel.screen == .storage || viewModel.screen == .storageManagement,
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
        .padding(.vertical, 10)
        .frame(width: 48)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? PopoverTheme.accent : PopoverTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? PopoverTheme.accentDim : Color.white.opacity(0.001))
                )
        }
        .frame(width: 40, height: 40)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    case .battery:
                        batteryScreen
                    case .ram:
                        ramScreen
                    case .storage:
                        storageScreen
                    case .storageManagement:
                        storageManagementScreen
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
        HStack(alignment: .firstTextBaseline) {
            Text(screenTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Spacer(minLength: 8)

            if viewModel.isStale {
                Text("Stale")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PopoverTheme.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(PopoverTheme.orangeDim)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var temperatureScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            thermalCard

            sectionSeparator

            if let snapshot = viewModel.snapshot {
                metricProgressCard(
                    title: "RAM",
                    usageText: MetricFormatter.usage(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                    percentText: MetricFormatter.percent(used: snapshot.memory.usedBytes, total: snapshot.memory.totalBytes),
                    ratio: snapshot.memory.usageRatio,
                    color: PopoverTheme.blue,
                    action: viewModel.showRAM
                )

                sectionSeparator

                metricProgressCard(
                    title: "Storage",
                    usageText: MetricFormatter.usage(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes),
                    percentText: MetricFormatter.percent(used: snapshot.storage.usedBytes, total: snapshot.storage.totalBytes),
                    ratio: snapshot.storage.usageRatio,
                    color: PopoverTheme.mint,
                    action: viewModel.showStorage
                )
            } else {
                collectingCard(text: "Collecting RAM and storage metrics...")
            }

            sectionSeparator

            simulationCard
        }
    }

    private var sectionSeparator: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private var thermalCard: some View {
        let state = displayedThermalState

        return Button(action: viewModel.showTemperature) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(thermalIndicatorFill(for: state))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: thermalSymbol(for: state))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(thermalColor(for: state))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(state.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(thermalColor(for: state))

                        if let lastUpdated = viewModel.snapshot?.timestamp {
                            Text(MetricFormatter.relativeTime(from: lastUpdated))
                                .font(.system(size: 10))
                                .foregroundStyle(PopoverTheme.textMuted)
                        }
                    }

                    Text(thermalDescription(for: state))
                        .font(.system(size: 11))
                        .foregroundStyle(PopoverTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private func metricProgressCard(
        title: String,
        usageText: String,
        percentText: String,
        ratio: Double,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    Spacer(minLength: 8)

                    Text(percentText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PopoverTheme.borderMedium)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(width: geometry.size.width * min(max(ratio, 0), 1))
                    }
                }
                .frame(height: 6)

                Text(usageText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private var simulationCard: some View {
        HStack(spacing: 4) {
            Text("Simulate")
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            ForEach(simulatedStates, id: \.self) { state in
                Button {
                    simulatedThermalState = state
                } label: {
                    Text(state.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(displayedThermalState == state ? PopoverTheme.accent : PopoverTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(displayedThermalState == state ? PopoverTheme.accentDim : Color.white.opacity(0.001))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ramScreen: some View {
        RAMDetailsView(
            viewModel: ramDetailsViewModel,
            memorySnapshot: viewModel.snapshot?.memory,
            onBack: {},
            showsBackButton: false
        )
    }

    private var batteryScreen: some View {
        BatteryScreenView(
            battery: viewModel.snapshot?.battery,
            settings: settings,
            coordinator: batteryPolicyCoordinator
        )
    }

    private func batterySummaryCard(_ battery: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Battery")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 8)

                Text((battery.percentage.map { "\($0)%" }) ?? "--")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.green)
            }

            if let percent = battery.percentage {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PopoverTheme.borderMedium)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PopoverTheme.green)
                            .frame(width: geometry.size.width * min(max(Double(percent) / 100.0, 0), 1))
                    }
                }
                .frame(height: 6)
            }

            Text("\(battery.chargeState.title) • \(battery.powerSource.title)")
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textSecondary)

            HStack(spacing: 6) {
                batteryChip(
                    title: battery.lowPowerModeEnabled ? "Low Power On" : "Low Power Off",
                    tint: battery.lowPowerModeEnabled ? PopoverTheme.yellow : PopoverTheme.textMuted
                )

                if let cycleCount = battery.cycleCount {
                    batteryChip(
                        title: "Cycles \(cycleCount)",
                        tint: PopoverTheme.textSecondary
                    )
                }
            }

            if let temperature = battery.temperatureCelsius {
                Text("Temp \(temperature)\u{00B0}C")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            if let health = battery.health, !health.isEmpty {
                Text("Health: \(health)")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            if let healthCondition = battery.healthCondition, !healthCondition.isEmpty {
                Text("Condition: \(healthCondition)")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func batteryChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.10))
            )
    }

    private var storageScreen: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 0) {
                    storageSummaryCard(snapshot.storage)

                    sectionSeparator

                    storageManageCard
                }
            } else {
                collectingCard(text: "Collecting storage metrics...")
            }
        }
    }

    private var storageManageCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Manager")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text("Scan apps, cache folders, and custom folders. Move selected items to Trash.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Button {
                viewModel.showStorageManagement()
            } label: {
                Text("Manage")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.accentContrastText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PopoverTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func storageSummaryCard(_ storage: StorageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Storage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 8)

                Text(MetricFormatter.percent(used: storage.usedBytes, total: storage.totalBytes))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.mint)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PopoverTheme.borderMedium)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PopoverTheme.mint)
                        .frame(width: geometry.size.width * min(max(storage.usageRatio, 0), 1))
                }
            }
            .frame(height: 6)

            HStack {
                Text(MetricFormatter.usage(used: storage.usedBytes, total: storage.totalBytes))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 4)

                Text("\(MetricFormatter.bytes(max(storage.totalBytes - storage.usedBytes, 0))) available")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func collectingCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(PopoverTheme.textMuted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsScreen: some View {
        SettingsView(
            settings: settings,
            ramPolicyViewModel: ramPolicyViewModel,
            appUpdateController: appUpdateController,
            onOpenPolicyManager: viewModel.showRAMPolicyManager
        )
    }

    private var policiesScreen: some View {
        RAMPolicySettingsView(
            viewModel: ramPolicyViewModel,
            onBack: viewModel.showSettings
        )
    }

    private var storageManagementScreen: some View {
        StorageManagementView(
            viewModel: storageManagementViewModel,
            onBack: viewModel.showStorage
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if appUpdateController.canRestartToInstallUpdate {
                Button {
                    appUpdateController.restartToInstallUpdate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Restart to Update")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(PopoverTheme.accentContrastText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PopoverTheme.orange)
                    )
                }
                .buttonStyle(.plain)
                .help("Install the downloaded update now.")
            } else {
                Text("MacMonitor")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textMuted)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textMuted)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
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
        case .battery:
            return "Battery"
        case .ram:
            return "RAM"
        case .storage:
            return "Storage"
        case .storageManagement:
            return "Storage Manager"
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

// MARK: - Theme Palette

struct ThemePalette {
    let bgDeep: Color
    let bgPanel: Color
    let bgCard: Color
    let bgCardHover: Color
    let bgElevated: Color

    let borderSubtle: Color
    let borderMedium: Color
    let borderActive: Color

    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    let accent: Color
    let accentDim: Color

    let blue: Color
    let blueDim: Color
    let blueGlow: Color

    let green: Color
    let greenDim: Color

    let yellow: Color
    let yellowDim: Color

    let orange: Color
    let orangeDim: Color

    let red: Color
    let redDim: Color

    let mint: Color
    let mintDim: Color

    let purple: Color
    let purpleDim: Color

    /// Toggle knob and accent-on-accent text color
    let accentContrastText: Color

    /// Toggle track off state
    let toggleOffTrack: Color
    let toggleOffKnob: Color
}

// MARK: - PopoverTheme (dynamic)

enum PopoverTheme {
    nonisolated(unsafe) private(set) static var current: ThemePalette = palette(for: .lime)

    @MainActor
    static func applyTheme(_ theme: AppTheme) {
        current = palette(for: theme)
    }

    // ── Convenience accessors (keeps every call site unchanged) ──

    static var bgDeep: Color { current.bgDeep }
    static var bgPanel: Color { current.bgPanel }
    static var bgCard: Color { current.bgCard }
    static var bgCardHover: Color { current.bgCardHover }
    static var bgElevated: Color { current.bgElevated }

    static var borderSubtle: Color { current.borderSubtle }
    static var borderMedium: Color { current.borderMedium }
    static var borderActive: Color { current.borderActive }

    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }
    static var textMuted: Color { current.textMuted }

    static var accent: Color { current.accent }
    static var accentDim: Color { current.accentDim }

    static var blue: Color { current.blue }
    static var blueDim: Color { current.blueDim }
    static var blueGlow: Color { current.blueGlow }

    static var green: Color { current.green }
    static var greenDim: Color { current.greenDim }

    static var yellow: Color { current.yellow }
    static var yellowDim: Color { current.yellowDim }

    static var orange: Color { current.orange }
    static var orangeDim: Color { current.orangeDim }

    static var red: Color { current.red }
    static var redDim: Color { current.redDim }

    static var mint: Color { current.mint }
    static var mintDim: Color { current.mintDim }

    static var purple: Color { current.purple }
    static var purpleDim: Color { current.purpleDim }

    static var accentContrastText: Color { current.accentContrastText }
    static var toggleOffTrack: Color { current.toggleOffTrack }
    static var toggleOffKnob: Color { current.toggleOffKnob }

    // ── Palette factory ──

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .lime:     return limePalette
        case .midnight: return midnightPalette
        case .cyber:    return cyberPalette
        case .daylight: return daylightPalette
        case .arctic:   return arcticPalette
        case .sand:     return sandPalette
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // DARK THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let limePalette = ThemePalette(
        bgDeep:          Color(hex: 0x1c1c1e),
        bgPanel:         Color(hex: 0x252527),
        bgCard:          Color(hex: 0x2c2c2e),
        bgCardHover:     Color(hex: 0x333336),
        bgElevated:      Color(hex: 0x2a2a2c),
        borderSubtle:    Color.white.opacity(0.08),
        borderMedium:    Color.white.opacity(0.12),
        borderActive:    Color(hex: 0xBFFF00, opacity: 0.40),
        textPrimary:     Color(hex: 0xededed),
        textSecondary:   Color(hex: 0x888888),
        textMuted:       Color(hex: 0x555555),
        accent:          Color(hex: 0xBFFF00),
        accentDim:       Color(hex: 0xBFFF00, opacity: 0.10),
        blue:            Color(hex: 0x3b82f6),
        blueDim:         Color(hex: 0x3b82f6, opacity: 0.10),
        blueGlow:        Color(hex: 0x3b82f6, opacity: 0.15),
        green:           Color(hex: 0xBFFF00),
        greenDim:        Color(hex: 0xBFFF00, opacity: 0.10),
        yellow:          Color(hex: 0xe6d400),
        yellowDim:       Color(hex: 0xe6d400, opacity: 0.10),
        orange:          Color(hex: 0xf97316),
        orangeDim:       Color(hex: 0xf97316, opacity: 0.10),
        red:             Color(hex: 0xef4444),
        redDim:          Color(hex: 0xef4444, opacity: 0.10),
        mint:            Color(hex: 0x2dd4bf),
        mintDim:         Color(hex: 0x2dd4bf, opacity: 0.10),
        purple:          Color(hex: 0xa78bfa),
        purpleDim:       Color(hex: 0xa78bfa, opacity: 0.10),
        accentContrastText: .black,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    private static let midnightPalette = ThemePalette(
        bgDeep:          Color(hex: 0x000000),
        bgPanel:         Color(hex: 0x0a0a0a),
        bgCard:          Color(hex: 0x111111),
        bgCardHover:     Color(hex: 0x1a1a1a),
        bgElevated:      Color(hex: 0x0d0d0d),
        borderSubtle:    Color.white.opacity(0.06),
        borderMedium:    Color.white.opacity(0.10),
        borderActive:    Color(hex: 0x3b82f6, opacity: 0.40),
        textPrimary:     Color(hex: 0xf0f0f0),
        textSecondary:   Color(hex: 0x7a7a7a),
        textMuted:       Color(hex: 0x444444),
        accent:          Color(hex: 0x3b82f6),
        accentDim:       Color(hex: 0x3b82f6, opacity: 0.12),
        blue:            Color(hex: 0x3b82f6),
        blueDim:         Color(hex: 0x3b82f6, opacity: 0.12),
        blueGlow:        Color(hex: 0x3b82f6, opacity: 0.15),
        green:           Color(hex: 0x22c55e),
        greenDim:        Color(hex: 0x22c55e, opacity: 0.12),
        yellow:          Color(hex: 0xeab308),
        yellowDim:       Color(hex: 0xeab308, opacity: 0.12),
        orange:          Color(hex: 0xf97316),
        orangeDim:       Color(hex: 0xf97316, opacity: 0.12),
        red:             Color(hex: 0xef4444),
        redDim:          Color(hex: 0xef4444, opacity: 0.12),
        mint:            Color(hex: 0x06b6d4),
        mintDim:         Color(hex: 0x06b6d4, opacity: 0.12),
        purple:          Color(hex: 0x8b5cf6),
        purpleDim:       Color(hex: 0x8b5cf6, opacity: 0.12),
        accentContrastText: .white,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    private static let cyberPalette = ThemePalette(
        bgDeep:          Color(hex: 0x0a0a0f),
        bgPanel:         Color(hex: 0x0f0f18),
        bgCard:          Color(hex: 0x141420),
        bgCardHover:     Color(hex: 0x1a1a2e),
        bgElevated:      Color(hex: 0x121220),
        borderSubtle:    Color(hex: 0x00ffff, opacity: 0.10),
        borderMedium:    Color(hex: 0x00ffff, opacity: 0.16),
        borderActive:    Color(hex: 0x00ffcc, opacity: 0.40),
        textPrimary:     Color(hex: 0xe0ffe0),
        textSecondary:   Color(hex: 0x66cc99),
        textMuted:       Color(hex: 0x336655),
        accent:          Color(hex: 0x00ffcc),
        accentDim:       Color(hex: 0x00ffcc, opacity: 0.10),
        blue:            Color(hex: 0x00ccff),
        blueDim:         Color(hex: 0x00ccff, opacity: 0.12),
        blueGlow:        Color(hex: 0x00ccff, opacity: 0.15),
        green:           Color(hex: 0x00ff66),
        greenDim:        Color(hex: 0x00ff66, opacity: 0.12),
        yellow:          Color(hex: 0xffff00),
        yellowDim:       Color(hex: 0xffff00, opacity: 0.12),
        orange:          Color(hex: 0xff6600),
        orangeDim:       Color(hex: 0xff6600, opacity: 0.12),
        red:             Color(hex: 0xff0066),
        redDim:          Color(hex: 0xff0066, opacity: 0.12),
        mint:            Color(hex: 0x00ffff),
        mintDim:         Color(hex: 0x00ffff, opacity: 0.12),
        purple:          Color(hex: 0xcc00ff),
        purpleDim:       Color(hex: 0xcc00ff, opacity: 0.12),
        accentContrastText: .black,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // LIGHT THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let daylightPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf7f6f3),
        bgPanel:         Color(hex: 0xeceae5),
        bgCard:          Color(hex: 0xffffff),
        bgCardHover:     Color(hex: 0xf5f4f1),
        bgElevated:      Color(hex: 0xfafaf8),
        borderSubtle:    Color.black.opacity(0.07),
        borderMedium:    Color.black.opacity(0.11),
        borderActive:    Color(hex: 0x65a30d, opacity: 0.40),
        textPrimary:     Color(hex: 0x1a1a18),
        textSecondary:   Color(hex: 0x5c5c56),
        textMuted:       Color(hex: 0xa0a098),
        accent:          Color(hex: 0x65a30d),
        accentDim:       Color(hex: 0x65a30d, opacity: 0.10),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x16a34a),
        greenDim:        Color(hex: 0x16a34a, opacity: 0.08),
        yellow:          Color(hex: 0xb45309),
        yellowDim:       Color(hex: 0xb45309, opacity: 0.08),
        orange:          Color(hex: 0xc2410c),
        orangeDim:       Color(hex: 0xc2410c, opacity: 0.08),
        red:             Color(hex: 0xdc2626),
        redDim:          Color(hex: 0xdc2626, opacity: 0.08),
        mint:            Color(hex: 0x0d9488),
        mintDim:         Color(hex: 0x0d9488, opacity: 0.08),
        purple:          Color(hex: 0x7c3aed),
        purpleDim:       Color(hex: 0x7c3aed, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )

    private static let arcticPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf0f4f8),
        bgPanel:         Color(hex: 0xe2e8f0),
        bgCard:          Color(hex: 0xffffff),
        bgCardHover:     Color(hex: 0xf1f5f9),
        bgElevated:      Color(hex: 0xf8fafc),
        borderSubtle:    Color(hex: 0x0f172a, opacity: 0.08),
        borderMedium:    Color(hex: 0x0f172a, opacity: 0.13),
        borderActive:    Color(hex: 0x2563eb, opacity: 0.35),
        textPrimary:     Color(hex: 0x0f172a),
        textSecondary:   Color(hex: 0x475569),
        textMuted:       Color(hex: 0x94a3b8),
        accent:          Color(hex: 0x2563eb),
        accentDim:       Color(hex: 0x2563eb, opacity: 0.08),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x059669),
        greenDim:        Color(hex: 0x059669, opacity: 0.08),
        yellow:          Color(hex: 0xca8a04),
        yellowDim:       Color(hex: 0xca8a04, opacity: 0.08),
        orange:          Color(hex: 0xea580c),
        orangeDim:       Color(hex: 0xea580c, opacity: 0.08),
        red:             Color(hex: 0xdc2626),
        redDim:          Color(hex: 0xdc2626, opacity: 0.08),
        mint:            Color(hex: 0x0891b2),
        mintDim:         Color(hex: 0x0891b2, opacity: 0.08),
        purple:          Color(hex: 0x7c3aed),
        purpleDim:       Color(hex: 0x7c3aed, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )

    private static let sandPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf5f0eb),
        bgPanel:         Color(hex: 0xe8e0d8),
        bgCard:          Color(hex: 0xfffefa),
        bgCardHover:     Color(hex: 0xf7f2ed),
        bgElevated:      Color(hex: 0xfaf7f4),
        borderSubtle:    Color(hex: 0x3c2814, opacity: 0.08),
        borderMedium:    Color(hex: 0x3c2814, opacity: 0.12),
        borderActive:    Color(hex: 0x0d9488, opacity: 0.35),
        textPrimary:     Color(hex: 0x1c1512),
        textSecondary:   Color(hex: 0x6b5c50),
        textMuted:       Color(hex: 0xa89888),
        accent:          Color(hex: 0x0d9488),
        accentDim:       Color(hex: 0x0d9488, opacity: 0.10),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x15803d),
        greenDim:        Color(hex: 0x15803d, opacity: 0.08),
        yellow:          Color(hex: 0xa16207),
        yellowDim:       Color(hex: 0xa16207, opacity: 0.08),
        orange:          Color(hex: 0xc2410c),
        orangeDim:       Color(hex: 0xc2410c, opacity: 0.08),
        red:             Color(hex: 0xb91c1c),
        redDim:          Color(hex: 0xb91c1c, opacity: 0.08),
        mint:            Color(hex: 0x0d9488),
        mintDim:         Color(hex: 0x0d9488, opacity: 0.08),
        purple:          Color(hex: 0x6d28d9),
        purpleDim:       Color(hex: 0x6d28d9, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )
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
                .fill(isOn ? PopoverTheme.accent : PopoverTheme.toggleOffTrack)
                .frame(width: 36, height: 20)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(isOn ? PopoverTheme.accentContrastText : PopoverTheme.toggleOffKnob)
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
