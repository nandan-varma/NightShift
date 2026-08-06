import SwiftUI
import AppKit

struct QuitButtonView: View {
    let gammaController: DisplayGammaController

    var body: some View {
        Button("Quit Twilight") {
            gammaController.restoreNeutral()
            NSApp.terminate(nil)
        }
        .font(.subheadline)
    }
}
