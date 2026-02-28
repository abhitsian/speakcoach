//
//  MeetingOverlayView.swift
//  SpeakCoach
//
//  Floating overlay for meeting mode — glassmorphic, modern macOS design.
//

import SwiftUI

struct MeetingOverlayView: View {
    @Bindable var content: MeetingOverlayContent
    var speechRecognizer: SpeechRecognizer
    var onTogglePoint: (UUID) -> Void
    var onEnd: () -> Void

    private var timeString: String {
        let t = Int(content.elapsedSeconds)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    // Pulsing recording dot
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: .red.opacity(0.5), radius: 4)
                        .opacity(content.isListening ? 1 : 0.3)

                    Text(timeString)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    onEnd()
                } label: {
                    Text("End Meeting")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.red.opacity(0.9))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Metrics strip
            HStack(spacing: 0) {
                metricCell(value: "\(Int(content.wordsPerMinute))", label: "WPM", icon: "gauge.medium")
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
                metricCell(value: "\(content.fillerCount)", label: "Fillers", icon: "bubble.left.and.exclamationmark.bubble.right")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Talking points
            if !content.talkingPoints.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TALKING POINTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1.2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(content.talkingPoints) { point in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        onTogglePoint(point.id)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .strokeBorder(.white.opacity(point.covered ? 0 : 0.3), lineWidth: 1.5)
                                                .frame(width: 18, height: 18)
                                            if point.covered {
                                                Circle()
                                                    .fill(.green)
                                                    .frame(width: 18, height: 18)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        Text(point.text)
                                            .font(.system(size: 13, weight: point.covered ? .regular : .medium))
                                            .foregroundStyle(point.covered ? .white.opacity(0.35) : .white.opacity(0.9))
                                            .strikethrough(point.covered, color: .white.opacity(0.2))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.bottom, 10)
            }

            // Separator
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Live transcript
            VStack(alignment: .leading, spacing: 0) {
                Text("LIVE TRANSCRIPT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1.2)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(speechRecognizer.fullTranscript.isEmpty
                             ? "Waiting for speech..."
                             : speechRecognizer.fullTranscript)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(speechRecognizer.fullTranscript.isEmpty
                                             ? .white.opacity(0.2)
                                             : .white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("bottom")
                    }
                    .onChange(of: speechRecognizer.fullTranscript) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            // Waveform
            HStack(spacing: 2) {
                ForEach(Array(speechRecognizer.audioLevels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            level > 0.3
                                ? .green.opacity(0.7)
                                : .white.opacity(0.35)
                        )
                        .frame(width: 4, height: max(3, level * 24))
                }
            }
            .frame(height: 26)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 340, height: 440)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.6))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
    }

    private func metricCell(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
