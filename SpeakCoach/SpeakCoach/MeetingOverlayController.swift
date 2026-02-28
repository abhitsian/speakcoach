//
//  MeetingOverlayController.swift
//  SpeakCoach
//
//  Manages the floating meeting mode overlay panel.
//

import AppKit
import SwiftUI
import Combine

@Observable
class MeetingOverlayContent {
    var talkingPoints: [TalkingPoint] = []
    var elapsedSeconds: TimeInterval = 0
    var fillerCount: Int = 0
    var fillerBreakdown: [String: Int] = [:]
    var wordsPerMinute: Double = 0
    var isListening: Bool = false
}

class MeetingOverlayController {
    var isShowing: Bool = false
    var onComplete: ((MeetingRecord) -> Void)?

    private var panel: NSPanel?
    private var speechRecognizer = SpeechRecognizer()
    private var analytics: SpeechAnalytics?
    private var cancellables = Set<AnyCancellable>()
    private var startTime: Date?
    private var overlayContent = MeetingOverlayContent()
    private var talkingPoints: [TalkingPoint] = []
    private var meetingTitle: String = ""

    func show(title: String, talkingPoints: [TalkingPoint]) {
        dismiss()

        self.meetingTitle = title
        self.talkingPoints = talkingPoints
        self.overlayContent.talkingPoints = talkingPoints
        self.overlayContent.elapsedSeconds = 0
        self.overlayContent.fillerCount = 0
        self.overlayContent.fillerBreakdown = [:]
        self.overlayContent.wordsPerMinute = 0
        self.startTime = Date()

        // Set up analytics
        if NotchSettings.shared.coachingEnabled {
            let a = SpeechAnalytics()
            a.startSession(sourceText: "")
            speechRecognizer.analyticsDelegate = a
            analytics = a
        }

        // Start speech recognition
        speechRecognizer.startListening()
        overlayContent.isListening = true

        // Create floating panel
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 400, height: 500)
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 420
        let xPos = screenFrame.maxX - panelWidth - 20
        let yPos = screenFrame.maxY - panelHeight - 20

        let content = MeetingOverlayView(
            content: overlayContent,
            speechRecognizer: speechRecognizer,
            onTogglePoint: { [weak self] id in
                self?.toggleTalkingPoint(id: id)
            },
            onEnd: { [weak self] in
                self?.endMeeting()
            }
        )

        let hostingView = NSHostingView(rootView: content)

        let p = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.contentView = hostingView
        p.orderFront(nil)
        self.panel = p
        self.isShowing = true

        // Timer to update elapsed time and metrics
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startTime else { return }
                self.overlayContent.elapsedSeconds = Date().timeIntervalSince(start)

                // Update live metrics from analytics
                if let a = self.analytics {
                    self.overlayContent.fillerCount = a.fillerWords.count
                    self.overlayContent.fillerBreakdown = Dictionary(
                        a.fillerWords.map { ($0.word.lowercased(), 1) },
                        uniquingKeysWith: +
                    )
                    let elapsed = self.overlayContent.elapsedSeconds
                    if elapsed > 5 {
                        let wordCount = self.speechRecognizer.fullTranscript
                            .split(separator: " ").count
                        self.overlayContent.wordsPerMinute = Double(wordCount) / (elapsed / 60.0)
                    }
                }

                self.overlayContent.isListening = self.speechRecognizer.isListening
            }
            .store(in: &cancellables)
    }

    private func toggleTalkingPoint(id: UUID) {
        if let i = talkingPoints.firstIndex(where: { $0.id == id }) {
            talkingPoints[i].covered.toggle()
            overlayContent.talkingPoints = talkingPoints
        }
    }

    func endMeeting() {
        guard isShowing, let start = startTime else { return }

        let duration = Date().timeIntervalSince(start)
        let transcript = speechRecognizer.fullTranscript
        let wordCount = transcript.split(separator: " ").count
        let wpm = duration > 5 ? Double(wordCount) / (duration / 60.0) : 0

        var fillerCount = 0
        var fillerBreakdown: [String: Int] = [:]
        var pauseCount = 0
        var totalPause: TimeInterval = 0
        var paceConsistency: Double = 1.0

        if let a = analytics {
            fillerCount = a.fillerWords.count
            fillerBreakdown = Dictionary(
                a.fillerWords.map { ($0.word.lowercased(), 1) },
                uniquingKeysWith: +
            )
            pauseCount = a.pauses.count
            totalPause = a.pauses.reduce(0) { $0 + $1.duration }
            paceConsistency = a.computePaceConsistency()
        }

        let record = MeetingRecord(
            id: UUID(),
            date: start,
            durationSeconds: duration,
            title: meetingTitle,
            talkingPoints: talkingPoints,
            transcript: transcript,
            wordsSpoken: wordCount,
            wordsPerMinute: wpm,
            fillerWordCount: fillerCount,
            fillerRate: wordCount > 0 ? Double(fillerCount) / Double(wordCount) : 0,
            fillerBreakdown: fillerBreakdown,
            pauseCount: pauseCount,
            totalPauseSeconds: totalPause,
            paceConsistency: paceConsistency
        )

        MeetingStore.shared.save(record)

        speechRecognizer.forceStop()
        speechRecognizer.analyticsDelegate = nil
        analytics = nil
        cancellables.removeAll()

        panel?.orderOut(nil)
        panel = nil
        isShowing = false
        startTime = nil

        onComplete?(record)
    }

    func dismiss() {
        speechRecognizer.forceStop()
        speechRecognizer.analyticsDelegate = nil
        analytics = nil
        cancellables.removeAll()
        panel?.orderOut(nil)
        panel = nil
        isShowing = false
        startTime = nil
    }
}
