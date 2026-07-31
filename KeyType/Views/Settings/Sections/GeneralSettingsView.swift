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
                        Label(icon.title, systemImage: icon.symbolName).tag(icon)
                    }
                }
                Picker("App logo", selection: $settings.appLogo) {
                    ForEach(AppLogo.allCases) { logo in
                        if logo == .writelong {
                            Label {
                                Text(logo.title)
                            } icon: {
                                Image("WritelongLogo")
                            }
                            .tag(logo)
                        } else {
                            Text(logo.title).tag(logo)
                        }
                    }
                }
                Text("The logo choice updates the app icon while Writelong is running.")
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
}
