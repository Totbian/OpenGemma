import SwiftUI

struct ModelManagerView: View {
    @Bindable var viewModel: ModelManagerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.availableModels) { model in
                        ModelRow(model: model, viewModel: viewModel)
                    }
                } header: {
                    Text("Available Models")
                } footer: {
                    Text("Models are downloaded from Hugging Face and run on-device via MLX. All inference is local — no data leaves your device.")
                }
            }
            .navigationTitle("Models")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: ModelInfo
    @Bindable var viewModel: ModelManagerViewModel

    private var isSelected: Bool {
        viewModel.selectedModelID == model.id
    }

    private var isLoading: Bool {
        isSelected && viewModel.isLoadingModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.headline)
                        Text(model.parameterCount)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            #if os(iOS)
                            .background(Color(.systemGray5))
                            #else
                            .background(Color.gray.opacity(0.2))
                            #endif
                            .clipShape(Capsule())
                    }
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected && !isLoading {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 4) {
                Text(model.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text("RAM: \(model.minimumRAMGB)+ GB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.loadingProgress)
                    Text("Downloading & loading model…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if isSelected {
                Label("Active", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button {
                    viewModel.selectAndLoadModel(model)
                } label: {
                    Label("Download & Load", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let error = viewModel.loadError, isSelected {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
