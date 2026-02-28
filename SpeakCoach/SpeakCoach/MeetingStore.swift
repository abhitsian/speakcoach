//
//  MeetingStore.swift
//  SpeakCoach
//
//  Persists meeting records to disk.
//

import Foundation

@Observable
class MeetingStore {
    static let shared = MeetingStore()

    private(set) var meetings: [MeetingRecord] = []

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SpeakCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("meetings.json")
    }

    init() {
        load()
    }

    func save(_ meeting: MeetingRecord) {
        meetings.insert(meeting, at: 0)
        if meetings.count > 500 {
            meetings = Array(meetings.prefix(500))
        }
        persist()
    }

    func delete(id: UUID) {
        meetings.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        meetings.removeAll()
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            meetings = try JSONDecoder().decode([MeetingRecord].self, from: data)
        } catch {
            meetings = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(meetings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail
        }
    }
}
