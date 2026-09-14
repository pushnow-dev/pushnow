import SwiftUI

struct SourceCreationSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let viewModel: SourcesViewModel
    let onSubmit: (SourceCreationInput) async -> Void

    @State private var name = ""
    @State private var sourceType: SourceConnectionType = .agent
    @State private var priority = "normal"
    @State private var pushEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("来源") {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("类型", selection: $sourceType) {
                        ForEach(SourceConnectionType.allCases) { type in
                            Text(verbatim: AppLocalization.text(type.label, locale: locale)).tag(type)
                        }
                    }
                }

                Section("默认提醒") {
                    Picker("级别", selection: $priority) {
                        Text("普通").tag("normal")
                        Text("重要").tag("important")
                        Text("P0").tag("P0")
                        Text("P1").tag("P1")
                    }

                    Toggle("App 推送", isOn: $pushEnabled)
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(JZColor.red)
                    }
                }
            }
            .navigationTitle("新建来源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text(viewModel.isWorking ? "创建中" : "创建", locale: locale)) {
                        Task {
                            await onSubmit(
                                SourceCreationInput(
                                    name: trimmedName,
                                    sourceType: sourceType,
                                    defaultPriority: priority,
                                    defaultPushEnabled: pushEnabled
                                )
                            )
                        }
                    }
                    .disabled(trimmedName.isEmpty || viewModel.isWorking)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    SourceCreationSheet(viewModel: SourcesViewModel()) { _ in }
}
