//
//  SessionStore.swift
//  SpeakCoach
//
//  Persists speech coaching sessions to disk.
//

import Foundation

@Observable
class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [SpeechSession] = []

    private static let maxSessions = 500

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SpeakCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    init() {
        load()
    }

    func save(_ session: SpeechSession) {
        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions = Array(sessions.prefix(Self.maxSessions))
        }
        persist()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        sessions.removeAll()
        persist()
    }

    func recentSessions(count: Int = 20) -> [SpeechSession] {
        Array(sessions.prefix(count))
    }

    func averageWPM(last n: Int = 10) -> Double? {
        let recent = Array(sessions.prefix(n))
        guard !recent.isEmpty else { return nil }
        return recent.map(\.wordsPerMinute).reduce(0, +) / Double(recent.count)
    }

    func averageFillerRate(last n: Int = 10) -> Double? {
        let recent = Array(sessions.prefix(n))
        guard !recent.isEmpty else { return nil }
        return recent.map(\.fillerRate).reduce(0, +) / Double(recent.count)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try JSONDecoder().decode([SpeechSession].self, from: data)
        } catch {
            sessions = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail — non-critical
        }
    }
}
