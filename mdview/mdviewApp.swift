import SwiftUI

@main
struct MdviewApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            DocumentView(document: file.document)
                .environment(settings)
        }
        .commands {
            CommandGroup(replacing: .printItem) {
                PrintMenuItem()
                ExportPDFMenuItem()
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}

private struct PrintMenuItem: View {
    @FocusedValue(\.printPreview) private var printAction

    var body: some View {
        Button("Print…") { printAction?() }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printAction == nil)
    }
}

private struct ExportPDFMenuItem: View {
    @FocusedValue(\.exportPDF) private var exportAction

    var body: some View {
        Button("Export as PDF…") { exportAction?() }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportAction == nil)
    }
}

private struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Editor") {
                HStack {
                    Text("Font size")
                    Slider(value: $settings.editorFontSize, in: 10...24, step: 1)
                    Text("\(Int(settings.editorFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
            }
            Section("Print") {
                Picker("Page size", selection: $settings.defaultPageSize) {
                    ForEach(AppSettings.PageSize.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .padding()
        .frame(width: 440, height: 260)
    }
}
