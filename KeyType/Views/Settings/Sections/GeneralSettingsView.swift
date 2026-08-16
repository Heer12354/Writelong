//
//  GeneralSettingsView.swift
//  KeyType
//
//  The "General" Settings pane: completion length. Split out of SettingsView so each sidebar
//  category lives in its own file.
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLogin.Toggle()
                Text("Start Writelong automatically when you log in to your Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Completion length") {
                Picker("Length", selection: $settings.completionLength) {
                    ForEach(CompletionLength.allCases) { length in
                        Text(length.title).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                Text("Shorter completions are more conservative; longer ones suggest more at once.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Menu bar icon", selection: $settings.menuBarIcon) {
                    ForEach(MenuBarIcon.allCases) { icon in
                        appearanceLabel(icon.title, assetName: icon.imageAssetName, symbolName: icon.symbolName)
                            .tag(icon)
                    }
                }
                Picker("App logo", selection: $settings.appLogo) {
                    ForEach(AppLogo.allCases) { logo in
                        appearanceLabel(logo.title, assetName: logo.imageAssetName)
                            .tag(logo)
                    }
                }
                Text("The app logo updates the Dock icon while Writelong is running. Choose any matching concept for the menu bar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Autocorrect") {
                Toggle("Enable autocorrect suggestions", isOn: $settings.autocorrectSuggestionsEnabled)
                Toggle("Show suggested fixes", isOn: $settings.showSuggestedFixes)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func appearanceLabel(_ title: String, assetName: String?, symbolName: String? = nil) -> some View {
        if let assetName {
            Label {
                Text(title)
            } icon: {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            }
        } else if let symbolName {
            Label(title, systemImage: symbolName)
        } else {
            Text(title)
        }
    }
}
