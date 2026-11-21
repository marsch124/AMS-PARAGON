import SwiftUI
import CoreLocation
import ParagonCore

/// Round 350 (capture-inbox, pick 32): **remember where you captured it.** A setting, off by
/// default (Settings › Place name). When it is on, each line saved from Quick capture ends in
/// ` — at <place>`, the place being the town, or the name of the spot, where the phone is.
///
/// **Nothing happens without permission.** Turning the setting on asks once. A capture never
/// asks, never waits more than a few seconds and never fails because of this: with no answer in
/// time, or no permission, the line is saved exactly as written. One look at the position, no
/// tracking; the place name is worked out on the device's own geocoder and kept nowhere.
@MainActor
final class CapturePlace: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CapturePlace()
    /// The setting, in `UserDefaults` (per device: a place is about where this device is).
    static let key = "capturePlaceName"
    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    /// True once the system has said yes. Published so Settings can say so.
    @Published private(set) var allowed = false
    /// True once the system has said no (or it is switched off for the whole device).
    @Published private(set) var refused = false

    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        readStatus()
    }

    private func readStatus() {
        let status = manager.authorizationStatus
        #if os(iOS)
        allowed = status == .authorizedWhenInUse || status == .authorizedAlways
        #else
        allowed = status == .authorizedAlways
        #endif
        refused = status == .denied || status == .restricted
    }

    /// Asks the system for permission. Called when the setting is switched on.
    func askPermission() {
        readStatus()
        guard !allowed, !refused else { return }
        #if os(iOS)
        manager.requestWhenInUseAuthorization()
        #else
        manager.requestAlwaysAuthorization()
        #endif
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.readStatus() }
    }

    // MARK: Looking once

    /// The place name now, or nil when the setting is off, there is no permission, nothing was
    /// found in time or the geocoder had no name. At most about four seconds.
    func name() async -> String? {
        guard Self.isOn else { return nil }
        readStatus()
        guard allowed, waiting == nil else { return nil }
        let found: CLLocation? = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            waiting = continuation
            manager.requestLocation()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                self.finish(nil)
            }
        }
        guard let location = found else { return nil }
        let geocoder = CLGeocoder()
        let marks: [CLPlacemark] = (try? await geocoder.reverseGeocodeLocation(location)) ?? []
        guard let mark = marks.first else { return nil }
        let spot: String? = mark.areasOfInterest?.first ?? mark.locality ?? mark.name
        return spot?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finish(_ location: CLLocation?) {
        guard let continuation = waiting else { return }
        waiting = nil
        continuation.resume(returning: location)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in self.finish(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}

/// Settings › Place name: one switch, off by default.
struct CapturePlaceSection: View {
    @AppStorage(CapturePlace.key) private var on = false
    @ObservedObject private var place = CapturePlace.shared

    var body: some View {
        Section {
            Toggle("Add the place name", isOn: $on)
                .accessibilityIdentifier("settings.capturePlace")
                .onChange(of: on) { _, now in
                    if now { place.askPermission() }
                }
            if on && place.refused {
                Text("PARAGON may not use the location. Turn it on in Settings, under PARAGON, Location.")
                    .font(Txt.label)
                    .foregroundStyle(Color.orange)
                    .accessibilityIdentifier("settings.capturePlace.refused")
            }
        } header: {
            Text("Place name")
        } footer: {
            Text("When this is on, a line saved from Quick capture or from the Inbox\u{2019}s own field ends with the place where you are, like \u{201C}Buy milk \u{2014} at Malm\u{F6}\u{201D}. PARAGON looks once, when you save, and keeps no track of where you go.")
        }
    }
}
