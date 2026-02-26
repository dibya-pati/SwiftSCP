import SwiftUI

@main
struct FileTransferApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1280, minHeight: 780)
                .onAppear {
                    viewModel.loadConnections()
                }
        }
        .defaultSize(width: 1400, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection") {
                    // Kept in UI sidebar for simplicity in this MVP.
                }
                .keyboardShortcut("n")
            }
        }
    }
}
