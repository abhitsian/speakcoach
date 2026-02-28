//
//  SpeechSession.swift
//  SpeakCoach
//
//  Speech coaching session data model.
//

import Foundation

struct SpeechSession: Codable, Identifiable {
    let id: UUID
    let date: Date
    let durationSeconds: TimeInterval
    let scriptSnippet: String
    let totalWords: Int
    let sourceWordCount: Int

    // Core metrics
    let wordsPerMinute: Double
    let fillerWordCount: Int
    let fillerRate: Double
    let fillerBreakdown: [String: Int]
    let pauseCount: Int
    let totalPauseSeconds: TimeInterval
    let averagePauseSeconds: TimeInterval
    let paceConsistency: Double        // stddev of inter-word intervals (lower = steadier)
    let scriptAccuracy: Double         // 0.0–1.0

    var effectiveSpeakingSeconds: TimeInterval {
        durationSeconds - totalPauseSeconds
    }
}
