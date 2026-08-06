import Testing
import Foundation
@testable import Twilight

struct SettingsStoreTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "com.nandanvarma.Twilight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsMatchDocumentedValues() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())

        #expect(store.dayColorTemperatureKelvin == 6500)
        #expect(store.nightColorTemperatureKelvin == 2700)
        #expect(store.transitionDurationMinutes == 60)
        #expect(store.scheduleMode == .auto)
        #expect(store.latitude == 0)
        #expect(store.longitude == 0)
        #expect(store.launchAtLoginEnabled == false)
        #expect(store.bedtimeRampEnabled == false)
        #expect(store.bedtimeHour == 23)
        #expect(store.bedtimeMinute == 0)
        #expect(store.bedtimeColorTemperatureKelvin == 2300)
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
