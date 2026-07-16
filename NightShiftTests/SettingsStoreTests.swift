import Testing
import Foundation
@testable import NightShift

struct SettingsStoreTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "com.nandanvarma.NightShift.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsMatchDocumentedValues() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())

        #expect(store.dayColorTemperatureKelvin == 6500)
        #expect(store.nightColorTemperatureKelvin == 3400)
        #expect(store.transitionDurationMinutes == 30)
        #expect(store.scheduleMode == .auto)
        #expect(store.latitude == 0)
        #expect(store.longitude == 0)
        #expect(store.launchAtLoginEnabled == false)
    }

    @Test func changesPersistAcrossInstancesSharingTheSameDefaults() {
        let defaults = makeIsolatedDefaults()

        let first = SettingsStore(defaults: defaults)
        first.nightColorTemperatureKelvin = 2700
        first.scheduleMode = .forceNight
        first.locationName = "Bengaluru"

        let second = SettingsStore(defaults: defaults)
        #expect(second.nightColorTemperatureKelvin == 2700)
        #expect(second.scheduleMode == .forceNight)
        #expect(second.locationName == "Bengaluru")
    }
}
