import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: BookFormViewModel

    var body: some View {
        Group {
            if viewModel.savedBooks.isEmpty {
                ContentUnavailableView(
                    "No books yet",
                    systemImage: "books.vertical",
                    description: Text("Every book you generate is saved here automatically.")
                )
            } else {
                List {
                    ForEach(viewModel.savedBooks) { book in
                        Button {
                            viewModel.openSavedBook(book)
                        } label: {
                            HStack {
                                if let thumb = BookStore.firstPageImage(for: book), let nsImage = NSImage(data: thumb) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 58)
                                        .clipShape(.rect(cornerRadius: 6))
                                } else {
                                    Image(systemName: "book.closed")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, height: 58)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(.headline)
                                    Text("\(book.pageCount) pages  \(book.createdAt.formatted(date: .abbreviated, time: .shortened))  $\(book.cost, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteSavedBook(book)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.savedBooks.isEmpty {
                Text(String(format: "%d books  Total spent: $%.2f", viewModel.savedBooks.count, viewModel.totalSpend))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
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
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.revealArchiveInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
        .navigationTitle("Library")
    }
}
