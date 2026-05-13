import EventLogCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: EventLogStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
        } detail: {
            DetailView(entry: store.selectedEntry, document: store.document)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.showImporter = true
                } label: {
                    Label("📂 Open", systemImage: "folder")
                }

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .searchable(text: $store.query, placement: .toolbar, prompt: "🔍 Search events")
        .fileImporter(
            isPresented: $store.showImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.load(url: url)
            }
        }
        .alert("⚠️ Could not load event log", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }
}
