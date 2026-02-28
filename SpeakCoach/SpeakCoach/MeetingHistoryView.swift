//
//  MeetingHistoryView.swift
//  SpeakCoach
//
//  Browse past meetings with transcripts, metrics, and visual stats.
//

import SwiftUI

// MARK: - Circular Progress Ring

struct ProgressRing: View {
    let progress: Double // 0...1
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    let meeting: MeetingRecord
    @Environment(\.dismiss) private var dismiss

    private var timeString: String {
        let t = Int(meeting.durationSeconds)
        let m = t / 60
        let s = t % 60
        return String(format: "%d:%02d", m, s)
    }

    private var fillerRate: Double {
        meeting.wordsSpoken > 0 ? Double(meeting.fillerWordCount) / Double(meeting.wordsSpoken) : 0
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(.system(size: 20, weight: .bold))
                    Text(Self.dateFormatter.string(from: meeting.date))
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
                    // Stat cards — 2x2 grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        statCard(
                            title: "Duration",
                            value: timeString,
                            subtitle: "\(meeting.wordsSpoken) words spoken",
                            ring: nil,
                            color: .blue
                        )
                        statCard(
                            title: "Pace",
                            value: "\(Int(meeting.wordsPerMinute))",
                            subtitle: wpmLabel,
                            ring: wpmProgress,
                            color: wpmColor
                        )
                        statCard(
                            title: "Filler Words",
                            value: "\(meeting.fillerWordCount)",
                            subtitle: meeting.fillerWordCount == 0 ? "None detected" : fillerSummary,
                            ring: fillerProgress,
                            color: fillerColor
                        )
                        statCard(
                            title: "Pauses",
                            value: "\(meeting.pauseCount)",
                            subtitle: meeting.pauseCount == 0 ? "No long pauses" : pauseSummary,
                            ring: nil,
                            color: .purple
                        )
                    }

                    // Filler breakdown
                    if !meeting.fillerBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Filler Breakdown")
                                .font(.system(size: 13, weight: .semibold))

                            let sorted = meeting.fillerBreakdown.sorted { $0.value > $1.value }
                            let maxCount = sorted.first?.value ?? 1
                            ForEach(sorted, id: \.key) { word, count in
                                HStack(spacing: 10) {
                                    Text(word)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(.orange.opacity(0.6))
                                            .frame(width: max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                                    }
                                    .frame(height: 8)
                                    Text("\(count)")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Talking points
                    if !meeting.talkingPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            let covered = meeting.talkingPoints.filter(\.covered).count
                            HStack {
                                Text("Talking Points")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(covered)/\(meeting.talkingPoints.count) covered")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(meeting.talkingPoints) { point in
                                HStack(spacing: 10) {
                                    Image(systemName: point.covered ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(point.covered ? .green : .secondary.opacity(0.5))
                                    Text(point.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(point.covered ? .primary : .secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Transcript
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Transcript")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if !meeting.transcript.isEmpty {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(meeting.transcript, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(meeting.transcript.isEmpty ? "No transcript recorded." : meeting.transcript)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(meeting.transcript.isEmpty ? .tertiary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 580)
        .background(.ultraThinMaterial)
    }

    // MARK: - Stat Card

    private func statCard(title: String, value: String, subtitle: String, ring: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let ring {
                    ProgressRing(progress: ring, color: color, size: 24, lineWidth: 3)
                }
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
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

    // MARK: - Metric Helpers

    private var wpmLabel: String {
        if meeting.wordsPerMinute > 180 { return "Fast pace" }
        if meeting.wordsPerMinute > 160 { return "Slightly fast" }
        if meeting.wordsPerMinute < 100 { return "Slow pace" }
        if meeting.wordsPerMinute < 120 { return "Slightly slow" }
        return "Good pace"
    }

    private var wpmColor: Color {
        if meeting.wordsPerMinute > 180 || meeting.wordsPerMinute < 100 { return .orange }
        if meeting.wordsPerMinute > 160 || meeting.wordsPerMinute < 120 { return .yellow }
        return .green
    }

    private var wpmProgress: Double {
        min(meeting.wordsPerMinute / 200.0, 1.0)
    }

    private var fillerSummary: String {
        let top = meeting.fillerBreakdown.sorted { $0.value > $1.value }.prefix(2)
        return top.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }

    private var fillerColor: Color {
        if fillerRate > 0.08 { return .red }
        if fillerRate > 0.04 { return .orange }
        return .green
    }

    private var fillerProgress: Double {
        min(fillerRate / 0.1, 1.0)
    }

    private var pauseSummary: String {
        let avgPause = meeting.pauseCount > 0 ? meeting.totalPauseSeconds / Double(meeting.pauseCount) : 0
        return String(format: "Avg %.1fs each", avgPause)
    }
}

// MARK: - Meeting History View

struct MeetingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeeting: MeetingRecord?
    @State private var deleteTarget: MeetingRecord?
    @State private var searchText = ""

    private var store: MeetingStore { MeetingStore.shared }

    private var filteredMeetings: [MeetingRecord] {
        if searchText.isEmpty { return store.meetings }
        let q = searchText.lowercased()
        return store.meetings.filter {
            $0.title.lowercased().contains(q) || $0.transcript.lowercased().contains(q)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Meetings")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Text("\(store.meetings.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search meetings...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // List
            if filteredMeetings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: store.meetings.isEmpty ? "waveform.and.mic" : "magnifyingglass")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text(store.meetings.isEmpty
                         ? "No meetings yet"
                         : "No results")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if store.meetings.isEmpty {
                        Text("Start a meeting to begin tracking\nyour speaking patterns.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredMeetings) { meeting in
                            meetingCard(meeting)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }

            // Footer
            HStack {
                if !store.meetings.isEmpty {
                    Button("Clear All") { store.clearAll() }
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .buttonStyle(.plain)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 540)
        .background(.ultraThinMaterial)
        .sheet(item: $selectedMeeting) { meeting in
            MeetingDetailView(meeting: meeting)
        }
        .alert("Delete Meeting?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let m = deleteTarget { store.delete(id: m.id) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
    }

    private func meetingCard(_ meeting: MeetingRecord) -> some View {
        Button {
            selectedMeeting = meeting
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(meeting.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(Self.dateFormatter.string(from: meeting.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                if !meeting.transcript.isEmpty {
                    Text(meeting.transcriptSnippet)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 14) {
                    let mins = Int(meeting.durationSeconds) / 60
                    metricTag(icon: "clock", text: "\(mins)m")
                    metricTag(icon: "gauge.medium", text: "\(Int(meeting.wordsPerMinute)) wpm")
                    if meeting.fillerWordCount > 0 {
                        metricTag(icon: "bubble.left", text: "\(meeting.fillerWordCount) fillers")
                    }
                    if !meeting.talkingPoints.isEmpty {
                        let covered = meeting.talkingPoints.filter(\.covered).count
                        metricTag(icon: "checklist", text: "\(covered)/\(meeting.talkingPoints.count)")
                    }
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { deleteTarget = meeting } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func metricTag(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.tertiary)
    }
}
