import SwiftUI

struct GenerationProgressView: View {
    @Bindable var viewModel: BookFormViewModel

    var body: some View {
        let pages = viewModel.generator.pages

        VStack(spacing: 24) {
            Text("Drawing your book...")
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            GlassEffectContainer {
                VStack(spacing: 16) {
                    ProgressView(
                        value: Double(viewModel.generator.completedCount),
                        total: Double(max(pages.count, 1))
                    )
                    .progressViewStyle(.linear)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(pages) { page in
                                HStack(spacing: 10) {
                                    statusIcon(for: page.status)
                                        .frame(width: 18)
                                    Text(page.subject)
                                        .lineLimit(1)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
                .padding(28)
                .glassEffect(in: .rect(cornerRadius: 24))
            }
            .frame(maxWidth: 480)

            Text("\(viewModel.generator.completedCount) of \(pages.count) pages")
                .foregroundStyle(.secondary)

            Button("Cancel", role: .cancel) {
                viewModel.cancelGeneration()
            }
            .buttonStyle(.glass)
        }
        .padding(40)
    }

    @ViewBuilder
    private func statusIcon(for status: PageStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle.dotted").foregroundStyle(.tertiary)
        case .generating:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
