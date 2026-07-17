import SwiftUI

struct ContentView: View {
    @State private var viewModel = BookFormViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.18), Color.pink.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.stage {
            case .form:
                BookFormView(viewModel: viewModel)
            case .generating:
                GenerationProgressView(viewModel: viewModel)
            case .preview:
                PageGridView(viewModel: viewModel)
            case .library:
                LibraryView(viewModel: viewModel)
            case .savedBook:
                SavedBookView(viewModel: viewModel)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
