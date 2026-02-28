//
//  ScriptLibrary.swift
//  SpeakCoach
//
//  Persists saved scripts to disk for the in-app library.
//

import Foundation

struct SavedScript: Codable, Identifiable {
    let id: UUID
    var title: String
    var pages: [String]
    let createdDate: Date
    var lastModifiedDate: Date

    var pageCount: Int { pages.count }

    var snippet: String {
        let text = pages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "…"
    }
}

@Observable
class ScriptLibrary {
    static let shared = ScriptLibrary()

    private(set) var scripts: [SavedScript] = []

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SpeakCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scripts.json")
    }

    init() {
        load()
    }

    func add(title: String, pages: [String]) {
        let script = SavedScript(
            id: UUID(),
            title: title,
            pages: pages,
            createdDate: Date(),
            lastModifiedDate: Date()
        )
        scripts.insert(script, at: 0)
        persist()
    }

    func update(_ script: SavedScript) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        persist()
    }

    func delete(id: UUID) {
        scripts.removeAll { $0.id == id }
        persist()
    }

    func rename(id: UUID, to newTitle: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].title = newTitle
        scripts[index].lastModifiedDate = Date()
        persist()
    }

    func overwrite(id: UUID, pages: [String]) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].pages = pages
        scripts[index].lastModifiedDate = Date()
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            scripts = try JSONDecoder().decode([SavedScript].self, from: data)
        } catch {
            scripts = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail
        }
    }
}
