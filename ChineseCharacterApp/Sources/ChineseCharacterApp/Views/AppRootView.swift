import SwiftUI

struct AppRootView: View {
    @StateObject private var deviceIdentity = DeviceIdentityStore()
    @StateObject private var accountStore = AccountStore()
    @StateObject private var favoriteStore = FavoriteCharacterStore()

    var body: some View {
        TabView {
            ContentView(
                deviceIdentity: deviceIdentity,
                accountStore: accountStore,
                favoriteStore: favoriteStore
            )
            .tabItem {
                Label("学习", systemImage: "pencil.and.scribble")
            }

            AccountSettingsView(
                deviceIdentity: deviceIdentity,
                accountStore: accountStore
            )
            .tabItem {
                Label("设置", systemImage: "person.crop.circle")
            }
        }
    }
}
