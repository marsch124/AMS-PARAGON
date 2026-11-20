import SwiftUI
import ParagonCore
#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

// Round 350: one line about today's steps and workouts in the daily note, under `## Health`.
// iPhone and iPad only; read only; off until the switch in Settings is turned on. Health is
// asked for permission only then, never at launch.

/// The setting's own key.
enum HealthLineSetting {
    static let key = "healthLineOn"
}

extension AppModel {
    /// Writes the day's health line into its daily note. **Never writes while notes are still
    /// coming from iCloud** (build 261's rule: a note that is not here yet is not an empty one),
    /// and never takes an earlier line away when Health has nothing to say right now. The
    /// section is the app's own, so the same line twice writes nothing.
    func writeHealthLine(_ line: String?, on day: DateOnly) {
        guard let line, let vault, notesWaitingForCloud.isEmpty, notesBeingUpdated.isEmpty else { return }
        flushPendingEdits()
        let existed: Bool = vault.dailyNoteExists(for: day)
        do {
            let note: Note = try vault.dailyNote(for: day)
            let updated: Note = HealthLine.note(note, settingLine: line)
            guard updated != note else { return }
            if save(updated), !existed { reload() }
        } catch {
            // The note is not here yet, or cannot be made: the next reading tries again.
        }
    }

    /// Asked for when PARAGON comes to the front. Nothing happens when the switch is off.
    func updateHealthLine() {
        #if canImport(HealthKit) && os(iOS)
        Task { await HealthLineWriter.shared.update(self, force: false) }
        #endif
    }
}

#if canImport(HealthKit) && os(iOS)
@MainActor
final class HealthLineWriter {
    static let shared = HealthLineWriter()
    private let store = HKHealthStore()
    private var lastRead: Date?
    private var running = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks Health for read access to steps and workouts. Called when the switch is turned on.
    func askPermission() async -> Bool {
        guard isAvailable, let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return false }
        let readTypes: Set<HKObjectType> = [steps, HKObjectType.workoutType()]
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Reads today and writes the line. At most once in half an hour unless `force`.
    func update(_ model: AppModel, force: Bool) async {
        guard UserDefaults.standard.bool(forKey: HealthLineSetting.key), isAvailable, !running else { return }
        let now = Date()
        guard force || HealthLine.isDue(lastRead: lastRead, now: now) else { return }
        running = true
        defer { running = false }
        let start: Date = Calendar.current.startOfDay(for: now)
        let steps: Int? = await stepCount(from: start, to: now)
        let workouts: [HealthWorkout] = await workoutsToday(from: start, to: now)
        lastRead = now
        model.writeHealthLine(HealthLine.wording(steps: steps, workouts: workouts), on: DateOnly.today())
    }

    private func stepCount(from start: Date, to end: Date) async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let health = store
        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, _ in
                let value: Double? = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count())
                if let value {
                    continuation.resume(returning: Int(value.rounded()))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            health.execute(query)
        }
    }

    private func workoutsToday(from start: Date, to end: Date) async -> [HealthWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let health = store
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HealthWorkout], Never>) in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let workouts: [HKWorkout] = (samples as? [HKWorkout]) ?? []
                var result: [HealthWorkout] = []
                for workout in workouts {
                    let minutes: Int = Int((workout.duration / 60).rounded())
                    result.append(HealthWorkout(name: HealthLineWriter.name(of: workout.workoutActivityType),
                                                minutes: minutes))
                }
                continuation.resume(returning: result)
            }
            health.execute(query)
        }
    }

    /// A short word for the kind of workout.
    nonisolated static func name(of type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walk"
        case .running: return "Run"
        case .cycling: return "Bike"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .dance: return "Dance"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}

/// Settings › Health line in the daily note. Off until switched on; turning it on asks Health.
struct HealthLineSection: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(HealthLineSetting.key) private var isOn = false
    @State private var note: String?

    var body: some View {
        Section {
            Toggle("Health line in the daily note", isOn: $isOn)
                .disabled(!HealthLineWriter.shared.isAvailable)
                .accessibilityIdentifier("settings.healthLine")
                .onChange(of: isOn) { _, on in
                    guard on else { note = nil; return }
                    Task {
                        let granted = await HealthLineWriter.shared.askPermission()
                        if granted {
                            await HealthLineWriter.shared.update(model, force: true)
                            note = nil
                        } else {
                            note = "Health did not allow it. You can change this in Settings > Health > Data Access."
                        }
                    }
                }
        } header: {
            Text("Health")
        } footer: {
            Text(note ?? "Writes one line under Health in today's daily note, for example Steps 8,412 · Walk 35 min. PARAGON only reads your steps and workouts. It never writes to Health.")
        }
    }
}
#endif
