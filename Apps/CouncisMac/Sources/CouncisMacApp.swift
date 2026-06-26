#if canImport(SwiftUI)
import SwiftUI

@main
struct CouncisMacApp: App {
    var body: some Scene {
        WindowGroup {
            CouncisRootView()
        }
        .windowStyle(.automatic)
    }
}
#else
@main
struct CouncisMacApp {
    static func main() {
        print("CouncisMac is a macOS SwiftUI app.")
    }
}
#endif
