import SwiftUI

struct BookFormView: View {
    @Bindable var viewModel: BookFormViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("ColourMe")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Make a printable colouring book in minutes")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            GlassEffectContainer {
                VStack(alignment: .leading, spacing: 18) {
                    if !viewModel.hasAPIKey {
                        HStack {
                            Image(systemName: "key.slash")
                            Text("Add your OpenRouter API key to get started.")
                            Spacer()
                            Button("Open Settings") { openSettings() }
                        }
                        .padding(10)
                        .background(.yellow.opacity(0.2), in: .rect(cornerRadius: 10))
                    }

                    LabeledContent("Theme") {
                        TextField("Dinosaurs, unicorns, space...", text: $viewModel.theme)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                    }

                    LabeledContent("Pages") {
                        Stepper(value: $viewModel.pageCount, in: Constants.pageCountRange) {
                            Text("\(viewModel.pageCount)")
                                .monospacedDigit()
                                .frame(minWidth: 28)
                        }
                    }

                    LabeledContent("Complexity") {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("", selection: $viewModel.complexity) {
                                ForEach(ComplexityLevel.allCases) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(viewModel.complexity.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 320)
                    }

                    LabeledContent("Child's name") {
                        TextField("Optional, shown on the cover", text: $viewModel.childName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                    }

                    LabeledContent("Print quality") {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("", selection: $viewModel.qualityTier) {
                                ForEach(QualityTier.allCases) { tier in
                                    Text(tier.displayName).tag(tier)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(viewModel.qualityTier.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 320)
                    }

                    LabeledContent("Cover") {
                        Toggle("Illustrated cover page", isOn: $viewModel.illustratedCover)
                            .toggleStyle(.checkbox)
                    }

                    LabeledContent("Model") {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("", selection: $viewModel.selectedModelID) {
                                if viewModel.availableModels.isEmpty {
                                    Text(viewModel.selectedModelID).tag(viewModel.selectedModelID)
                                } else {
                                    ForEach(viewModel.availableModels) { model in
                                        if let price = model.priceLabel(tier: viewModel.qualityTier) {
                                            Text("\(model.displayName)  \(price)").tag(model.id)
                                        } else {
                                            Text(model.displayName).tag(model.id)
                                        }
                                    }
                                }
                            }
                            .labelsHidden()

                            if let estimate = viewModel.estimatedBookCostLabel {
                                Text(estimate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: 320)
                    }
                }
                .padding(28)
                .glassEffect(in: .rect(cornerRadius: 24))
            }
            .frame(maxWidth: 520)

            Button {
                viewModel.generate()
            } label: {
                Label("Generate Book", systemImage: "paintpalette")
                    .font(.title3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.canGenerate)
        }
        .padding(40)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.openLibrary()
                } label: {
                    Label("Library", systemImage: "books.vertical")
                }
            }
        }
        .task { await viewModel.loadModels() }
        .onChange(of: viewModel.hasAPIKey) {
            Task { await viewModel.loadModels() }
        }
    }
}
