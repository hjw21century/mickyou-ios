import SwiftUI

@main struct PocketSpeakerApp: App {
    @StateObject private var server = SpeakerServer()
    var body: some Scene { WindowGroup { ContentView().environmentObject(server) }.windowResizability(.contentSize) }
}
