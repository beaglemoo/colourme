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
                                Image(systemName: "book.closed")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.startOver()
                } label: {
                    Label("New Book", systemImage: "arrow.backward")
                }
            }
        }
        .navigationTitle("Library")
    }
}
