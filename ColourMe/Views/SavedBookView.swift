import SwiftUI

struct SavedBookView: View {
    @Bindable var viewModel: BookFormViewModel

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(Array(viewModel.openedBookImages.enumerated()), id: \.offset) { index, imageData in
                    VStack(spacing: 8) {
                        if let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        }
                        if let subject = viewModel.openedBook?.subjects[safe: index] {
                            Text(subject)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        if viewModel.moveTargets.isEmpty {
                            Text("No other books to move to")
                        } else {
                            Menu("Move to") {
                                ForEach(viewModel.moveTargets) { target in
                                    Button(target.title) {
                                        viewModel.movePage(at: index, to: target)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)

            if let book = viewModel.openedBook {
                Text(String(format: "Generated %@ for $%.2f", book.createdAt.formatted(date: .abbreviated, time: .omitted), book.cost))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.openLibrary()
                } label: {
                    Label("Library", systemImage: "arrow.backward")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.printOpenedBook()
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .disabled(viewModel.openedBookImages.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.exportOpenedBookPDF()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.openedBookImages.isEmpty)
            }
        }
        .navigationTitle(viewModel.openedBook?.title ?? "Book")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
