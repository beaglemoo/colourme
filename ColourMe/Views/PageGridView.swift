import SwiftUI

struct PageGridView: View {
    @Bindable var viewModel: BookFormViewModel

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(viewModel.generator.pages) { page in
                    PageThumbnailView(page: page) {
                        Task { await viewModel.regenerate(pageID: page.id) }
                    }
                }
            }
            .padding(28)

            if viewModel.generator.totalCost > 0 {
                Text(String(format: "This book cost $%.2f to generate", viewModel.generator.totalCost))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.startOver()
                } label: {
                    Label("New Book", systemImage: "arrow.backward")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.generator.pages.allSatisfy { $0.status.imageData == nil })
            }
        }
        .navigationTitle("Preview")
    }
}
