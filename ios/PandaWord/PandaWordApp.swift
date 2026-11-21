import SwiftUI

@main
struct PandaWordApp: App {
    @StateObject private var model = WordModel()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(model).tint(Color(red: 0.15, green: 0.65, blue: 0.60)) }
    }
}
