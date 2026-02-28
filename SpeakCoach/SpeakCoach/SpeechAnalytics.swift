//
//  SpeechAnalytics.swift
//  SpeakCoach
//
//  Real-time speech metrics collector for coaching.
//

import Foundation
import Speech

@Observable
class SpeechAnalytics {
    private(set) var sessionStartDate = Date()
    private(set) var wordTimestamps: [(word: String, timestamp: TimeInterval)] = []
    private(set) var fillerWords: [(word: String, timestamp: TimeInterval)] = []
    private(set) var pauses: [(start: TimeInterval, duration: TimeInterval)] = []

    private var sourceText: String = ""
    private var sourceWords: [String] = []
    private var processedSegmentCount: Int = 0
    private var lastSegmentTimestamp: TimeInterval = 0
    private var sessionStartTime: TimeInterval = 0
    private var audioLevelSamples: [(timestamp: TimeInterval, level: CGFloat)] = []

    static let pauseThresholdSeconds: TimeInterval = 2.0

    static let defaultFillerWords: Set<String> = [
        "um", "uh", "uh huh", "hmm", "like", "you know",
        "basically", "actually", "literally", "so",
        "right", "well", "i mean", "okay", "ok"
    ]

    var fillerWordSet: Set<String> = SpeechAnalytics.defaultFillerWords

    func startSession(sourceText: String) {
        self.sessionStartDate = Date()
        self.sessionStartTime = CACurrentMediaTime()
        self.sourceText = sourceText
        self.sourceWords = sourceText.split(separator: " ").map { String($0).lowercased() }
        self.wordTimestamps = []
        self.fillerWords = []
        self.pauses = []
        self.processedSegmentCount = 0
        self.lastSegmentTimestamp = 0

        // Merge custom filler words from settings
        let custom = NotchSettings.shared.customFillerWords
        if !custom.isEmpty {
            let extras = custom.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            for word in extras where !word.isEmpty {
                fillerWordSet.insert(word)
            }
        }
    }

    /// Called when a new page starts mid-session so segment tracking resets
    /// but accumulated metrics carry over.
    func resetSegmentTracking() {
        processedSegmentCount = 0
    }

    func recordAudioLevel(_ level: CGFloat) {
        let elapsed = CACurrentMediaTime() - sessionStartTime
        audioLevelSamples.append((timestamp: elapsed, level: level))
    }

    func recordSegments(_ segments: [SFTranscriptionSegment]) {
        guard segments.count > processedSegmentCount else { return }

        let newSegments = segments[processedSegmentCount...]
        for segment in newSegments {
            let word = segment.substring.lowercased()
            let timestamp = segment.timestamp

            wordTimestamps.append((word: word, timestamp: timestamp))

            // Detect filler words
            if fillerWordSet.contains(word) {
                fillerWords.append((word: word, timestamp: timestamp))
            }

            // Detect pauses (gap between consecutive segments)
            if lastSegmentTimestamp > 0 {
                let gap = timestamp - lastSegmentTimestamp
                if gap >= Self.pauseThresholdSeconds {
                    pauses.append((start: lastSegmentTimestamp, duration: gap))
                }
            }
            lastSegmentTimestamp = timestamp + segment.duration
        }
        processedSegmentCount = segments.count
    }

    func finalize() -> SpeechSession? {
        let duration = CACurrentMediaTime() - sessionStartTime
        guard duration > 1 else { return nil }

        let totalSpoken = wordTimestamps.count
        let totalPause = pauses.map(\.duration).reduce(0, +)
        let effectiveSpeaking = max(duration - totalPause, 1)
        let wpm = Double(totalSpoken) / (effectiveSpeaking / 60.0)

        // Filler breakdown
        var breakdown: [String: Int] = [:]
        for filler in fillerWords {
            breakdown[filler.word, default: 0] += 1
        }
        let fillerRate = totalSpoken > 0 ? Double(fillerWords.count) / Double(totalSpoken) : 0

        // Pace consistency: stddev of inter-word intervals
        let paceConsistency = computePaceConsistency()

        // Script accuracy: what fraction of source words were spoken
        let accuracy = computeScriptAccuracy()

        let snippet = String(sourceText.prefix(100))

        return SpeechSession(
            id: UUID(),
            date: sessionStartDate,
            durationSeconds: duration,
            scriptSnippet: snippet,
            totalWords: totalSpoken,
            sourceWordCount: sourceWords.count,
            wordsPerMinute: wpm,
            fillerWordCount: fillerWords.count,
            fillerRate: fillerRate,
            fillerBreakdown: breakdown,
            pauseCount: pauses.count,
            totalPauseSeconds: totalPause,
            averagePauseSeconds: pauses.isEmpty ? 0 : totalPause / Double(pauses.count),
            paceConsistency: paceConsistency,
            scriptAccuracy: accuracy
        )
    }

    func computePaceConsistency() -> Double {
        guard wordTimestamps.count > 2 else { return 0 }
        var intervals: [Double] = []
        for i in 1..<wordTimestamps.count {
            let delta = wordTimestamps[i].timestamp - wordTimestamps[i - 1].timestamp
            // Skip intervals that are clearly pauses
            if delta < Self.pauseThresholdSeconds {
                intervals.append(delta)
            }
        }
        guard intervals.count > 1 else { return 0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
        return sqrt(variance)
    }

    private func computeScriptAccuracy() -> Double {
        guard !sourceWords.isEmpty else { return 1.0 }
        let spokenSet = wordTimestamps.map { $0.word.filter { $0.isLetter || $0.isNumber } }
        var matched = 0
        var spokenIndex = 0

        for srcWord in sourceWords {
            let normalized = srcWord.filter { $0.isLetter || $0.isNumber }
            if normalized.isEmpty { matched += 1; continue }

            // Look ahead in spoken words for a match
            var found = false
            let searchEnd = min(spokenIndex + 5, spokenSet.count)
            for j in spokenIndex..<searchEnd {
                if spokenSet[j] == normalized || fuzzyMatch(spokenSet[j], normalized) {
                    matched += 1
                    spokenIndex = j + 1
                    found = true
                    break
                }
            }
            if !found {
                // Skip ahead in spoken to not get stuck
                spokenIndex = min(spokenIndex + 1, spokenSet.count)
            }
        }
        return Double(matched) / Double(sourceWords.count)
    }

    private func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a.isEmpty || b.isEmpty { return false }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        let shorter = min(a.count, b.count)
        let shared = zip(a, b).prefix(while: { $0 == $1 }).count
        return shorter >= 3 && shared >= shorter * 3 / 5
    }
}
