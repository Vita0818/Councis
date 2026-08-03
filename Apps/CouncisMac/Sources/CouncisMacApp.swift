#if COUNCIS_APP && canImport(SwiftUI)
import SwiftUI

@main
struct CouncisMacApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup(AppIdentity.displayName) {
            IntatisMacRootView().environmentObject(env)
        }
        .defaultSize(width: 1100, height: 760)
    }
}
#elseif COUNCIS_APP
@main
struct CouncisMacApp {
    static func main() {
        print("CouncisMac is a macOS SwiftUI app and only runs on macOS.")
    }
}
#endif
