import SwiftUI

struct LocationSectionView: View {
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.subheadline)
            LocationSearchView(settings: settings)
        }
    }
}
