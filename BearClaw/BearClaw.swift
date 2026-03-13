import SwiftUI

@main
struct BearClaw: App {
    @StateObject private var settings: AppSettingsStore
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        let settings = AppLaunch.makeSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _chatViewModel = StateObject(
            wrappedValue: ChatViewModel(clientProvider: { settings.makeClient() })
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(settings: settings, chatViewModel: chatViewModel)
        }
    }
}
