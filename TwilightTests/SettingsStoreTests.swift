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

    @Test func newFeatureDefaultsMatchDocumentedValues() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())

        #expect(store.wakeRampEnabled == false)
        #expect(store.wakeHour == 7)
        #expect(store.wakeMinute == 0)
        #expect(store.suspendUntil == nil)
        #expect(store.customWarmStartHour == 22)
        #expect(store.customWarmStartMinute == 0)
        #expect(store.customWarmEndHour == 6)
        #expect(store.customWarmEndMinute == 0)
        #expect(store.menuBarIconName == "")
        #expect(store.displayOffsets.isEmpty)
    }

    @Test func suspendAndCustomSchedulePersistAcrossInstances() {
        let defaults = makeIsolatedDefaults()

        let first = SettingsStore(defaults: defaults)
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        first.suspendUntil = until
        first.customWarmStartHour = 21
        first.customWarmStartMinute = 30
        first.displayOffsets = ["abc": -300]

        let second = SettingsStore(defaults: defaults)
        #expect(second.suspendUntil == until)
        #expect(second.customWarmStartHour == 21)
        #expect(second.customWarmStartMinute == 30)
        #expect(second.displayOffsets == ["abc": -300])
    }

    @Test func changingModeClearsAnActiveSuspension() {
        let store = SettingsStore(defaults: makeIsolatedDefaults())
        store.suspendUntil = Date().addingTimeInterval(3600)
        #expect(store.suspendUntil != nil)

        store.scheduleMode = .forceNight
        #expect(store.suspendUntil == nil)
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
