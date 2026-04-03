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
                    Text("Models are downloaded from Hugging Face and stored on-device. All inference runs locally — no data leaves your device.")
                }

                if !viewModel.downloadedModels.isEmpty {
                    Section("Storage") {
                        let totalBytes = viewModel.downloadedModels.reduce(0) { $0 + $1.sizeInBytes }
                        let totalGB = Double(totalBytes) / 1_073_741_824
                        LabeledContent("Downloaded Models", value: "\(viewModel.downloadedModels.count)")
                        LabeledContent("Total Size", value: String(format: "%.1f GB", totalGB))
                    }
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
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
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.selectedModelID == model.id {
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

            // Download / Status controls
            if viewModel.isDownloading(model) {
                downloadingView
            } else if viewModel.isDownloaded(model) {
                downloadedView
            } else {
                downloadButton
            }

            if let error = viewModel.errorMessage(for: model) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var downloadingView: some View {
        VStack(spacing: 6) {
            ProgressView(value: viewModel.progress(for: model))
            HStack {
                Text("\(Int(viewModel.progress(for: model) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Pause") { viewModel.pause(model) }
                    .font(.caption)
                Button("Cancel") { viewModel.cancelDownload(model) }
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var downloadedView: some View {
        HStack {
            if viewModel.selectedModelID == model.id {
                Label("Active", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button {
                    viewModel.selectModel(model)
                } label: {
                    Text("Select")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.deleteModel(model)
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
            .controlSize(.small)
        }
    }

    private var downloadButton: some View {
        Button {
            viewModel.download(model)
        } label: {
            Label("Download", systemImage: "arrow.down.circle")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

#Preview {
    ModelManagerView(
        viewModel: ModelManagerViewModel(downloadService: ModelDownloadService())
    )
}
