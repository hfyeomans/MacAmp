import Foundation
import Observation

@MainActor
@Observable
final class RadioStationLibrary {
    private(set) var stations: [RadioStation] = []

    private let userDefaultsKey = "MacAmp.RadioStations"

    init() {
        loadStations()
    }

    func addStation(_ station: RadioStation) {
        // Check for duplicates
        if stations.contains(where: { $0.streamURL == station.streamURL }) {
            return
        }

        stations.append(station)
        saveStations()
    }

    func removeStation(id: UUID) {
        stations.removeAll { $0.id == id }
        saveStations()
    }

    func removeAll() {
        stations.removeAll()
        saveStations()
    }

    // MARK: - Persistence

    private func saveStations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stations)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            AppLog.error(.audio, "Failed to save radio stations: \(error)")
        }
    }

    private func loadStations() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }

        do {
            let decoder = JSONDecoder()
            stations = try decoder.decode([RadioStation].self, from: data)
        } catch {
            AppLog.error(.audio, "Failed to load radio stations: \(error)")
            stations = []
        }
    }
}
