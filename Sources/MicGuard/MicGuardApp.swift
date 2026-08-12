import SwiftUI

@main
struct MicGuardApp: App {

    @State private var model = MicGuardModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
    }
}
