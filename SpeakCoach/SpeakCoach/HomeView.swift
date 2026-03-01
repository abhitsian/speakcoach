//
//  HomeView.swift
//  SpeakCoach
//
//  Home dashboard — stats, quick actions, recent activity.
//

import SwiftUI

struct HomeView: View {
    var onNewScript: () -> Void
    var onStartMeeting: () -> Void
    var onOpenLibrary: () -> Void
    var onPresentCurrent: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                quickActionsRow
                statsSection
                recentActivitySection
                engagementSection
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Header

extension HomeView {
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold))
                Text(streakText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var streakText: String {
        let streak = HomeDataProvider.practiceStreak()
        let total = HomeDataProvider.totalSessionCount() + HomeDataProvider.totalMeetingCount()
        if streak > 1 { return "\(streak)-day practice streak" }
        if total > 0 { return "\(total) total sessions" }
        return "Ready to practice"
    }
}

// MARK: - Quick Actions

extension HomeView {
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            actionCard(icon: "doc.badge.plus", label: "New Script", color: .blue, action: onNewScript)
            actionCard(icon: "waveform.and.mic", label: "Meeting", color: .orange, action: onStartMeeting)
            actionCard(icon: "books.vertical", label: "Library", color: .purple, action: onOpenLibrary)
            actionCard(icon: "play.fill", label: "Present", color: .green, action: onPresentCurrent)
        }
    }

    private func actionCard(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats

extension HomeView {
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.system(size: 15, weight: .semibold))

            let hasData = HomeDataProvider.totalSessionCount() > 0

            if hasData {
                statsCards
            } else {
                statsEmpty
            }
        }
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            scoreCard
            wpmCard
            fillerCard
            practiceTimeCard
            countCard
        }
    }

    private var scoreCard: some View {
        let score = HomeDataProvider.averageScore() ?? 0
        let pct = Int(score * 100)
        let color: Color = score > 0.8 ? .green : (score > 0.6 ? .yellow : .orange)
        return VStack(spacing: 8) {
            ZStack {
                ProgressRing(progress: score, color: color, size: 40, lineWidth: 4)
                Text("\(pct)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text("Score")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var wpmCard: some View {
        let avg = SessionStore.shared.averageWPM() ?? 0
        let trend = HomeDataProvider.wpmTrend()
        return statCardView(
            value: "\(Int(avg))",
            label: "Avg WPM",
            trend: trend
        )
    }

    private var fillerCard: some View {
        let avg = SessionStore.shared.averageFillerRate() ?? 0
        let pct = String(format: "%.1f%%", avg * 100)
        let trend = HomeDataProvider.fillerTrend()
        return statCardView(
            value: pct,
            label: "Filler Rate",
            trend: trend
        )
    }

    private var practiceTimeCard: some View {
        let time = HomeDataProvider.totalPracticeTime()
        return statCardView(
            value: HomeDataProvider.formatDuration(time),
            label: "Practice",
            trend: nil
        )
    }

    private var countCard: some View {
        let s = HomeDataProvider.totalSessionCount()
        let m = HomeDataProvider.totalMeetingCount()
        return statCardView(
            value: "\(s + m)",
            label: "\(s) sessions, \(m) meetings",
            trend: nil
        )
    }

    private func statCardView(value: String, label: String, trend: TrendDirection?) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let t = trend {
                    Image(systemName: t.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(t.color)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statsEmpty: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Text("Complete your first session to see stats here.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Recent Activity

extension HomeView {
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 15, weight: .semibold))

            let items = recentItems
            if items.isEmpty {
                recentEmpty
            } else {
                recentList(items)
            }
        }
    }

    private var recentItems: [ActivityItem] {
        let sessions: [ActivityItem] = SessionStore.shared.sessions.prefix(5).map { s in
            let score = HomeDataProvider.sessionScore(s)
            return ActivityItem(
                id: s.id, type: .session,
                title: s.scriptSnippet.isEmpty ? "Practice Session" : s.scriptSnippet,
                date: s.date,
                metric: "\(Int(score * 100)) score",
                metricColor: score > 0.8 ? .green : (score > 0.6 ? .yellow : .orange)
            )
        }
        let meetings: [ActivityItem] = MeetingStore.shared.meetings.prefix(5).map { m in
            return ActivityItem(
                id: m.id, type: .meeting,
                title: m.title,
                date: m.date,
                metric: "\(Int(m.wordsPerMinute)) wpm",
                metricColor: .blue
            )
        }
        return (sessions + meetings).sorted { $0.date > $1.date }.prefix(5).map { $0 }
    }

    private func recentList(_ items: [ActivityItem]) -> some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                activityRow(item)
            }
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.type == .session ? "play.circle.fill" : "waveform.circle.fill")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(item.type == .session ? Color.accentColor : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.dateString)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(item.metric)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(item.metricColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.metricColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var recentEmpty: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Text("Your recent sessions and meetings will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Engagement

extension HomeView {
    private var engagementSection: some View {
        let hasData = HomeDataProvider.totalSessionCount() > 0 || HomeDataProvider.totalMeetingCount() > 0
        return Group {
            if hasData {
                engagementGrid
            }
        }
    }

    private var engagementGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                personalBestsCard
                topFillerCard
            }
            HStack(spacing: 12) {
                weeklyGoalCard
                coachingTipCard
            }
        }
    }

    private var personalBestsCard: some View {
        let best = HomeDataProvider.bestScore()
        let lowFiller = HomeDataProvider.lowestFillerRate()
        let longest = HomeDataProvider.longestSession()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Personal Bests")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let b = best {
                bestRow(icon: "star.fill", label: "Best Score", value: "\(Int(b * 100))", color: .yellow)
            }
            if let f = lowFiller {
                bestRow(icon: "hand.thumbsup.fill", label: "Lowest Fillers", value: String(format: "%.1f%%", f * 100), color: .green)
            }
            if let l = longest {
                bestRow(icon: "timer", label: "Longest", value: HomeDataProvider.formatDuration(l), color: .blue)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bestRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }

    private var topFillerCard: some View {
        let top = HomeDataProvider.topFillerWord()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Top Filler Word")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let t = top {
                VStack(spacing: 6) {
                    Text("\"\(t.word)\"")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("used \(t.count) times total")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("No filler words detected yet!")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var weeklyGoalCard: some View {
        let count = HomeDataProvider.sessionsThisWeek()
        let goal = 5
        let progress = min(Double(count) / Double(goal), 1.0)
        let color: Color = count >= goal ? .green : .accentColor
        return VStack(spacing: 10) {
            Text("This Week")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(progress: progress, color: color, size: 48, lineWidth: 5)
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) of \(goal) sessions")
                        .font(.system(size: 13, weight: .medium))
                    Text(count >= goal ? "Goal reached!" : "\(goal - count) more to go")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var coachingTipCard: some View {
        let tip = HomeDataProvider.coachingTip()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("Coaching Tip")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(tip)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Activity Item Model

private struct ActivityItem: Identifiable {
    let id: UUID
    let type: ActivityType
    let title: String
    let date: Date
    let metric: String
    let metricColor: Color

    enum ActivityType {
        case session, meeting
    }

    var dateString: String {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
