//
//  HomeDataProvider.swift
//  SpeakCoach
//
//  Stateless computation helpers for the home dashboard.
//

import SwiftUI

enum TrendDirection {
    case improving, declining, stable

    var icon: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .declining: return "arrow.up.right"
        case .stable: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .orange
        case .stable: return .secondary
        }
    }

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
}

enum HomeDataProvider {

    // MARK: - Score

    static func sessionScore(_ s: SpeechSession) -> Double {
        var score = 0.0
        let wpmDist = abs(s.wordsPerMinute - 145) / 60.0
        score += max(0, 1.0 - wpmDist) * 0.25
        score += max(0, 1.0 - s.fillerRate * 10) * 0.25
        score += max(0, 1.0 - s.paceConsistency) * 0.25
        score += s.scriptAccuracy * 0.25
        return min(max(score, 0), 1.0)
    }

    static func averageScore(last n: Int = 10) -> Double? {
        let recent = Array(SessionStore.shared.sessions.prefix(n))
        guard !recent.isEmpty else { return nil }
        return recent.map { sessionScore($0) }.reduce(0, +) / Double(recent.count)
    }

    // MARK: - Trends

    static func wpmTrend() -> TrendDirection {
        let sessions = SessionStore.shared.sessions
        guard sessions.count >= 4 else { return .stable }
        let recent = sessions.prefix(3).map(\.wordsPerMinute)
        let older = sessions.dropFirst(3).prefix(3).map(\.wordsPerMinute)
        guard !older.isEmpty else { return .stable }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let recentDist = abs(recentAvg - 145)
        let olderDist = abs(olderAvg - 145)
        let diff = olderDist - recentDist
        if diff > 5 { return .improving }
        if diff < -5 { return .declining }
        return .stable
    }

    static func fillerTrend() -> TrendDirection {
        let sessions = SessionStore.shared.sessions
        guard sessions.count >= 4 else { return .stable }
        let recent = sessions.prefix(3).map(\.fillerRate)
        let older = sessions.dropFirst(3).prefix(3).map(\.fillerRate)
        guard !older.isEmpty else { return .stable }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let diff = olderAvg - recentAvg
        if diff > 0.01 { return .improving }
        if diff < -0.01 { return .declining }
        return .stable
    }

    // MARK: - Practice Streak

    static func practiceStreak() -> Int {
        let cal = Calendar.current
        let sessionDates = SessionStore.shared.sessions.map { cal.startOfDay(for: $0.date) }
        let meetingDates = MeetingStore.shared.meetings.map { cal.startOfDay(for: $0.date) }
        let allDates = Set(sessionDates + meetingDates).sorted(by: >)

        guard let latest = allDates.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        let daysSince = cal.dateComponents([.day], from: latest, to: today).day ?? 0
        guard daysSince <= 1 else { return 0 }

        var streak = 1
        var current = latest
        for date in allDates.dropFirst() {
            guard let expected = cal.date(byAdding: .day, value: -1, to: current) else { break }
            if cal.isDate(date, inSameDayAs: expected) {
                streak += 1
                current = date
            } else if !cal.isDate(date, inSameDayAs: current) {
                break
            }
        }
        return streak
    }

    // MARK: - Totals

    static func totalPracticeTime() -> TimeInterval {
        let s = SessionStore.shared.sessions.map(\.durationSeconds).reduce(0, +)
        let m = MeetingStore.shared.meetings.map(\.durationSeconds).reduce(0, +)
        return s + m
    }

    static func totalSessionCount() -> Int {
        SessionStore.shared.sessions.count
    }

    static func totalMeetingCount() -> Int {
        MeetingStore.shared.meetings.count
    }

    // MARK: - Personal Bests

    static func bestScore() -> Double? {
        let sessions = SessionStore.shared.sessions
        guard !sessions.isEmpty else { return nil }
        return sessions.map { sessionScore($0) }.max()
    }

    static func lowestFillerRate() -> Double? {
        let sessions = SessionStore.shared.sessions
        guard !sessions.isEmpty else { return nil }
        return sessions.map(\.fillerRate).min()
    }

    static func longestSession() -> TimeInterval? {
        let sessionMax = SessionStore.shared.sessions.map(\.durationSeconds).max()
        let meetingMax = MeetingStore.shared.meetings.map(\.durationSeconds).max()
        switch (sessionMax, meetingMax) {
        case let (s?, m?): return max(s, m)
        case let (s?, nil): return s
        case let (nil, m?): return m
        case (nil, nil): return nil
        }
    }

    // MARK: - Top Filler Word

    static func topFillerWord() -> (word: String, count: Int)? {
        var agg: [String: Int] = [:]
        for s in SessionStore.shared.sessions {
            for (w, c) in s.fillerBreakdown { agg[w, default: 0] += c }
        }
        for m in MeetingStore.shared.meetings {
            for (w, c) in m.fillerBreakdown { agg[w, default: 0] += c }
        }
        guard let top = agg.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value)
    }

    // MARK: - Weekly Goal

    static func sessionsThisWeek() -> Int {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        let s = SessionStore.shared.sessions.filter { $0.date >= start }.count
        let m = MeetingStore.shared.meetings.filter { $0.date >= start }.count
        return s + m
    }

    // MARK: - Coaching Tip

    static func coachingTip() -> String {
        let sessions = SessionStore.shared.sessions
        guard !sessions.isEmpty else {
            return "Complete your first session to get personalized coaching tips."
        }
        let recent = Array(sessions.prefix(5))
        let avgWPM = recent.map(\.wordsPerMinute).reduce(0, +) / Double(recent.count)
        let avgFiller = recent.map(\.fillerRate).reduce(0, +) / Double(recent.count)
        let avgConsistency = recent.map(\.paceConsistency).reduce(0, +) / Double(recent.count)

        if avgWPM > 180 {
            return "You've been speaking fast lately (\(Int(avgWPM)) WPM avg). Try pausing between sentences."
        }
        if avgWPM < 100 {
            return "Your recent pace is \(Int(avgWPM)) WPM. A slightly faster delivery keeps listeners engaged."
        }
        if avgFiller > 0.05 {
            if let top = topFillerWord() {
                return "Your most common filler is \"\(top.word)\". Try replacing it with a brief silent pause."
            }
            return "Your filler rate is elevated. Practice pausing silently instead of using filler words."
        }
        if avgConsistency > 0.4 {
            return "Your pacing varies quite a bit. Try reading at a steady, deliberate rhythm."
        }
        return "Your recent sessions look solid. Keep practicing to maintain your streak!"
    }

    // MARK: - Formatting

    static func formatDuration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
