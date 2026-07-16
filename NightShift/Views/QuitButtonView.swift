import SwiftUI
import AppKit

struct QuitButtonView: View {
    let gammaController: DisplayGammaController

    var body: some View {
        Button("Quit NightShift") {
            gammaController.restoreNeutral()
            NSApp.terminate(nil)
        }
        .font(.subheadline)
    }
}
