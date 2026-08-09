import SwiftUI

// MARK: - Alert Percent + Toggle Row

/// Row with a numeric percent text field and an enable/disable toggle.
@MainActor
func settingsAlertPercentToggleRow(
    title: String,
    selection: Binding<Int>,
    isOn: Binding<Bool>,
    theme: SettingsTheme
) -> some View {
    let enabled = isOn.wrappedValue
    return HStack(alignment: .center, spacing: 10) {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textMain)
        Spacer(minLength: 8)
        HStack(spacing: 6) {
            TextField("", value: selection, formatter: SettingsTheme.integerFormatter)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .frame(width: 44)
            Text("%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .frame(width: SettingsTheme.pickerWidth, alignment: .trailing)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.6)
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(theme.toggleTint)
    }
}

// MARK: - Alert Picker + Toggle Row

/// Row with a menu picker for a typed option and an enable/disable toggle.
@MainActor
func settingsAlertPickerToggleRow<Option: Hashable>(
    title: String,
    selection: Binding<Option>,
    options: [Option],
    isOn: Binding<Bool>,
    theme: SettingsTheme,
    optionTitle: @escaping (Option) -> String
) -> some View {
    let enabled = isOn.wrappedValue
    return HStack(alignment: .center, spacing: 10) {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textMain)
        Spacer(minLength: 8)
        Menu {
            ForEach(options, id: \.self) { option in
                Button { selection.wrappedValue = option } label: {
                    Text(optionTitle(option))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(optionTitle(selection.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(enabled ? theme.textMain : theme.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: SettingsTheme.pickerWidth, alignment: .trailing)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .opacity(enabled ? 1.0 : 0.6)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(!enabled)
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(theme.toggleTint)
    }
}

// MARK: - Alert Picker Row (no toggle)

/// Row with a menu picker only (no separate toggle).
@MainActor
func settingsAlertPickerRow<Option: Hashable>(
    title: String,
    selection: Binding<Option>,
    options: [Option],
    theme: SettingsTheme,
    optionTitle: @escaping (Option) -> String
) -> some View {
    HStack(alignment: .center, spacing: 12) {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textMain)
        Spacer(minLength: 8)
        Menu {
            ForEach(options, id: \.self) { option in
                Button { selection.wrappedValue = option } label: {
                    Text(optionTitle(option))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(optionTitle(selection.wrappedValue))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(theme.textMain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: SettingsTheme.pickerWidth, alignment: .leading)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .frame(width: SettingsTheme.pickerWidth, alignment: .trailing)
    }
}
