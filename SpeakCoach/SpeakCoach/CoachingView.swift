//
//  CoachingView.swift
//  SpeakCoach
//
//  Post-session coaching report and session history — visual, modern design.
//

import SwiftUI

// MARK: - Post-Session Report

struct SessionReportView: View {
    let session: SpeechSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Report")
                        .font(.system(size: 20, weight: .bold))
                    HStack(spacing: 6) {
                        Text(session.date, style: .date)
                        Text("  ")
                        Text(formatDuration(session.durationSeconds))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)

            ScrollView {
                VStack(spacing: 20) {
                    // Main score ring
                    HStack(spacing: 24) {
                        // Overall score
                        ZStack {
                            ProgressRing(progress: overallScore, color: overallColor, size: 80, lineWidth: 6)
                            VStack(spacing: 0) {
                                Text("\(Int(overallScore * 100))")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(overallColor)
                                Text("score")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Quick stats
                        VStack(alignment: .leading, spacing: 8) {
                            quickStat(label: "Words", value: "\(session.totalWords)")
                            quickStat(label: "Pace", value: "\(Int(session.wordsPerMinute)) WPM")
                            quickStat(label: "Fillers", value: "\(session.fillerWordCount)")
                            quickStat(label: "Accuracy", value: "\(Int(session.scriptAccuracy * 100))%")
                        }
                    }
                    .padding(20)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Metric cards — 2-column grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        metricCard(
                            title: "Pace",
                            value: "\(Int(session.wordsPerMinute))",
                            unit: "WPM",
                            subtitle: wpmLabel,
                            progress: min(session.wordsPerMinute / 200.0, 1.0),
                            color: wpmColor
                        )
                        metricCard(
                            title: "Fillers",
                            value: "\(session.fillerWordCount)",
                            unit: session.fillerWordCount == 1 ? "word" : "words",
                            subtitle: fillerDetail,
                            progress: min(session.fillerRate / 0.1, 1.0),
                            color: fillerColor
                        )
                        metricCard(
                            title: "Steadiness",
                            value: steadinessLabel,
                            unit: "",
                            subtitle: steadinessDetail,
                            progress: 1.0 - min(session.paceConsistency, 1.0),
                            color: steadinessColor
                        )
                        metricCard(
                            title: "Accuracy",
                            value: "\(Int(session.scriptAccuracy * 100))%",
                            unit: "",
                            subtitle: accuracyDetail,
                            progress: session.scriptAccuracy,
                            color: accuracyColor
                        )
                    }

                    // Coaching tips
                    if !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Coaching Tips")
                                .font(.system(size: 13, weight: .semibold))
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.yellow)
                                        .padding(.top, 1)
                                    Text(tip)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.yellow.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 440, height: 560)
        .background(.ultraThinMaterial)
    }

    // MARK: - Components

    private func quickStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }

    private func metricCard(title: String, value: String, unit: String, subtitle: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressRing(progress: progress, color: color, size: 22, lineWidth: 2.5)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    // MARK: - Score

    private var overallScore: Double {
        var score = 0.0
        // Pace (25%)
        let wpmDist = abs(session.wordsPerMinute - 145) / 60.0
        score += max(0, 1.0 - wpmDist) * 0.25
        // Fillers (25%)
        score += max(0, 1.0 - session.fillerRate * 10) * 0.25
        // Steadiness (25%)
        score += max(0, 1.0 - session.paceConsistency) * 0.25
        // Accuracy (25%)
        score += session.scriptAccuracy * 0.25
        return min(max(score, 0), 1.0)
    }

    private var overallColor: Color {
        if overallScore > 0.8 { return .green }
        if overallScore > 0.6 { return .yellow }
        return .orange
    }

    // MARK: - Metric Labels

    private var wpmLabel: String {
        if session.wordsPerMinute > 180 { return "Fast — try slowing down" }
        if session.wordsPerMinute > 160 { return "Slightly fast" }
        if session.wordsPerMinute < 100 { return "Slow — pick up the pace" }
        if session.wordsPerMinute < 120 { return "Slightly slow" }
        return "Good conversational pace"
    }

    private var wpmColor: Color {
        if session.wordsPerMinute > 180 || session.wordsPerMinute < 100 { return .orange }
        if session.wordsPerMinute > 160 || session.wordsPerMinute < 120 { return .yellow }
        return .green
    }

    private var fillerDetail: String {
        if session.fillerWordCount == 0 { return "None detected" }
        let top = session.fillerBreakdown.sorted { $0.value > $1.value }.prefix(3)
        return top.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }

    private var fillerColor: Color {
        if session.fillerRate > 0.08 { return .red }
        if session.fillerRate > 0.04 { return .orange }
        return .green
    }

    private var steadinessLabel: String {
        if session.paceConsistency < 0.2 { return "Steady" }
        if session.paceConsistency < 0.4 { return "Moderate" }
        return "Uneven"
    }

    private var steadinessDetail: String {
        if session.paceConsistency < 0.2 { return "Very consistent rhythm" }
        if session.paceConsistency < 0.4 { return "Some variation in pace" }
        return "Pace jumps around"
    }

    private var steadinessColor: Color {
        if session.paceConsistency < 0.2 { return .green }
        if session.paceConsistency < 0.4 { return .yellow }
        return .orange
    }

    private var accuracyDetail: String {
        if session.scriptAccuracy > 0.9 { return "Closely followed the script" }
        if session.scriptAccuracy > 0.7 { return "Mostly on-script" }
        return "Significant deviation"
    }

    private var accuracyColor: Color {
        if session.scriptAccuracy > 0.9 { return .green }
        if session.scriptAccuracy > 0.7 { return .yellow }
        return .orange
    }

    private var tips: [String] {
        var result: [String] = []
        if session.wordsPerMinute > 180 {
            result.append("You spoke at \(Int(session.wordsPerMinute)) WPM. Try deliberately pausing between sentences.")
        } else if session.wordsPerMinute < 100 {
            result.append("At \(Int(session.wordsPerMinute)) WPM, try a slightly faster delivery to keep listeners engaged.")
        }
        if session.fillerRate > 0.05 {
            let topFiller = session.fillerBreakdown.max(by: { $0.value < $1.value })?.key ?? "um"
            result.append("You used \"\(topFiller)\" frequently. Replace fillers with a brief silent pause.")
        }
        if session.paceConsistency > 0.4 {
            result.append("Your pace varied a lot. Try reading to a steady beat.")
        }
        if session.scriptAccuracy < 0.7 {
            result.append("You deviated from the script. Read through it once silently first.")
        }
        if result.isEmpty {
            result.append("Solid session. Pace, filler usage, and accuracy all look good.")
        }
        return result
    }
}

// MARK: - Session History

struct SessionHistoryView: View {
    @Bindable var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: SpeechSession?
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session History")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if !store.sessions.isEmpty {
                    Button("Clear All") { showClearConfirmation = true }
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Trend cards
            if store.sessions.count >= 2 {
                trendSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }

            // Sessions
            if store.sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("No sessions yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Complete a reading session with\ncoaching enabled to see your history.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.sessions) { session in
                            sessionCard(session)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }

            // Footer
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 540)
        .background(.ultraThinMaterial)
        .sheet(item: $selectedSession) { session in
            SessionReportView(session: session)
        }
        .alert("Clear All Sessions?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) { store.clearAll() }
        } message: {
            Text("This will permanently delete all session history.")
        }
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        HStack(spacing: 12) {
            trendCard(label: "Avg WPM", value: store.averageWPM().map { "\(Int($0))" } ?? "--", trend: wpmTrend)
            trendCard(label: "Avg Fillers", value: store.averageFillerRate().map { "\(Int($0 * 100))%" } ?? "--", trend: fillerTrend)
            trendCard(label: "Sessions", value: "\(store.sessions.count)", trend: nil)
        }
    }

    private func trendCard(label: String, value: String, trend: TrendDirection?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if let trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trend.color)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private enum TrendDirection {
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
    }

    private var wpmTrend: TrendDirection? {
        guard store.sessions.count >= 4 else { return nil }
        let recent = store.sessions.prefix(3).map(\.wordsPerMinute).reduce(0, +) / 3
        let older = store.sessions.dropFirst(3).prefix(3).map(\.wordsPerMinute).reduce(0, +) / Double(min(3, store.sessions.count - 3))
        let diff = recent - older
        if abs(diff) < 5 { return .stable }
        let recentDist = abs(recent - 145)
        let olderDist = abs(older - 145)
        return recentDist < olderDist ? .improving : .declining
    }

    private var fillerTrend: TrendDirection? {
        guard store.sessions.count >= 4 else { return nil }
        let recent = store.sessions.prefix(3).map(\.fillerRate).reduce(0, +) / 3
        let older = store.sessions.dropFirst(3).prefix(3).map(\.fillerRate).reduce(0, +) / Double(min(3, store.sessions.count - 3))
        let diff = recent - older
        if abs(diff) < 0.01 { return .stable }
        return diff < 0 ? .improving : .declining
    }

    // MARK: - Session Card

    private func sessionCard(_ session: SpeechSession) -> some View {
        Button {
            selectedSession = session
        } label: {
            HStack(spacing: 14) {
                // Mini score ring
                ZStack {
                    ProgressRing(progress: sessionScore(session), color: scoreColor(sessionScore(session)), size: 36, lineWidth: 3)
                    Text("\(Int(sessionScore(session) * 100))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(sessionScore(session)))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.date, style: .date)
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 12) {
                        Text("\(Int(session.wordsPerMinute)) wpm")
                        Text("\(session.fillerWordCount) fillers")
                        Text("\(Int(session.scriptAccuracy * 100))% acc")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func sessionScore(_ s: SpeechSession) -> Double {
        var score = 0.0
        let wpmDist = abs(s.wordsPerMinute - 145) / 60.0
        score += max(0, 1.0 - wpmDist) * 0.25
        score += max(0, 1.0 - s.fillerRate * 10) * 0.25
        score += max(0, 1.0 - s.paceConsistency) * 0.25
        score += s.scriptAccuracy * 0.25
        return min(max(score, 0), 1.0)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score > 0.8 { return .green }
        if score > 0.6 { return .yellow }
        return .orange
    }
}
