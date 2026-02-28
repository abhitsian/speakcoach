//
//  MeetingRecord.swift
//  SpeakCoach
//
//  Data model for meeting sessions with transcripts and talking points.
//

import Foundation

struct TalkingPoint: Codable, Identifiable {
    let id: UUID
    var text: String
    var covered: Bool

    init(text: String, covered: Bool = false) {
        self.id = UUID()
        self.text = text
        self.covered = covered
    }
}

struct MeetingRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    var title: String
    var talkingPoints: [TalkingPoint]
    var transcript: String

    // Metrics
    let wordsSpoken: Int
    let wordsPerMinute: Double
    let fillerWordCount: Int
    let fillerRate: Double
    let fillerBreakdown: [String: Int]
    let pauseCount: Int
    let totalPauseSeconds: TimeInterval
    let paceConsistency: Double

    var effectiveSpeakingSeconds: TimeInterval {
        durationSeconds - totalPauseSeconds
    }

    var transcriptSnippet: String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "…"
    }
}
