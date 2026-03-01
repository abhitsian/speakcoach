//
//  ContentView.swift
//  SpeakCoach
//
//
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var service = SpeakCoachService.shared
    @State private var isRunning = false
    @State private var isDroppingPresentation = false
    @State private var dropError: String?
    @State private var dropAlertTitle: String = "Import Error"
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var completedSession: SpeechSession?
    @State private var showSessionHistory = false
    @State private var showLibrary = false
    @State private var showMeetingHistory = false
    @State private var isMeetingRunning = false
    @State private var completedMeeting: MeetingRecord?
    @State private var meetingTitle = ""
    @State private var talkingPointsText = ""
    @State private var showMeetingSetup = false
    @State private var showingHome = true
    @FocusState private var isTextFocused: Bool

    private let defaultText = """
Welcome to SpeakCoach! Your teleprompter and speech coach, right below the notch. [smile]

As you read aloud, words highlight in real-time. When you finish, you'll get a coaching report with your pace, filler words, pauses, and accuracy. [pause]

Try reading this passage now. Speak at a natural pace and avoid filler words like um and uh. The waveform at the bottom shows your voice activity. [nod]

After each session, SpeakCoach tracks your metrics over time so you can see yourself improving. Open Settings and go to the Coaching tab to customize what gets measured.

Happy speaking! [wave]
"""

    private var languageLabel: String {
        let locale = NotchSettings.shared.speechLocale
        return Locale.current.localizedString(forIdentifier: locale)
            ?? locale
    }

    private var currentText: Binding<String> {
        Binding(
            get: {
                guard service.currentPageIndex < service.pages.count else { return "" }
                return service.pages[service.currentPageIndex]
            },
            set: { newValue in
                guard service.currentPageIndex < service.pages.count else { return }
                service.pages[service.currentPageIndex] = newValue
            }
        )
    }

    private var hasAnyContent: Bool {
        service.pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var wordCount: Int {
        guard service.currentPageIndex < service.pages.count else { return 0 }
        return service.pages[service.currentPageIndex]
            .split(separator: " ").count
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left navigation sidebar
            navSidebar

            // Main content
            if showingHome {
                HomeView(
                    onNewScript: {
                        service.pages = [""]
                        service.currentPageIndex = 0
                        service.currentFileURL = nil
                        service.savedPages = [""]
                        showingHome = false
                        isTextFocused = true
                    },
                    onStartMeeting: { showMeetingSetup = true },
                    onOpenLibrary: { showLibrary = true },
                    onPresentCurrent: {
                        if hasAnyContent { showingHome = false; run() }
                    }
                )
            } else {
                editorContent
            }
        }
        .alert(dropAlertTitle, isPresented: Binding(get: { dropError != nil }, set: { if !$0 { dropError = nil } })) {
            Button("OK") { dropError = nil }
        } message: {
            Text(dropError ?? "")
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: NotchSettings.shared)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(item: $completedSession) { session in
            SessionReportView(session: session)
        }
        .sheet(isPresented: $showSessionHistory) {
            SessionHistoryView(store: SessionStore.shared)
        }
        .sheet(isPresented: $showLibrary) {
            ScriptLibraryView { script in
                service.loadFromLibrary(script)
                showingHome = false
            }
        }
        .sheet(isPresented: $showMeetingHistory) {
            MeetingHistoryView()
        }
        .sheet(isPresented: $showMeetingSetup) {
            meetingSetupSheet
        }
        .sheet(item: $completedMeeting) { meeting in
            MeetingDetailView(meeting: meeting)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAbout)) { _ in
            showAbout = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isRunning = service.overlayController.isShowing
        }
        .onChange(of: service.currentFileURL) { _, _ in
            showingHome = false
        }
        .onAppear {
            if service.pages.count == 1 && service.pages[0].isEmpty {
                service.pages[0] = defaultText
            }
            if service.overlayController.isShowing {
                isRunning = true
            }
            if SpeakCoachService.shared.launchedExternally {
                DispatchQueue.main.async {
                    for window in NSApp.windows where !(window is NSPanel) {
                        window.orderOut(nil)
                    }
                }
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        ZStack {
            VStack(spacing: 0) {
                    // Editor
                    TextEditor(text: currentText)
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .focused($isTextFocused)

                    // Bottom status bar
                    HStack(spacing: 16) {
                        Text("Page \(service.currentPageIndex + 1) of \(service.pages.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text("\(wordCount) words")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                        if let url = service.currentFileURL {
                            HStack(spacing: 4) {
                                if service.pages != service.savedPages {
                                    Circle().fill(.orange).frame(width: 5, height: 5)
                                }
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(NotchSettings.shared.listeningMode.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.02))
                }

                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            // Meeting button
                            Button {
                                if isMeetingRunning {
                                    service.meetingController.endMeeting()
                                    isMeetingRunning = false
                                } else {
                                    showMeetingSetup = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isMeetingRunning ? "stop.fill" : "waveform.and.mic")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(isMeetingRunning ? "End" : "Meeting")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(isMeetingRunning ? Color.red : Color.orange))
                                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)

                            // Present button
                            Button {
                                if isRunning { stop() } else { run() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(isRunning ? "Stop" : "Present")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(isRunning ? Color.red : Color.accentColor))
                                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isRunning && !hasAnyContent)
                            .opacity(!hasAnyContent && !isRunning ? 0.35 : 1)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
                }

                // Drop zone overlay
                if isDroppingPresentation {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Color.accentColor)
                        Text("Drop PowerPoint (.pptx) file")
                            .font(.system(size: 14, weight: .semibold))
                        Text("For Keynote or Google Slides,\nexport as PPTX first.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .background(Color.accentColor.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 16)))
                    )
                    .padding(12)
                }

                // Invisible drop target
                Color.clear
                    .contentShape(Rectangle())
                    .onDrop(of: [.fileURL], isTargeted: $isDroppingPresentation) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            guard let url else { return }
                            let ext = url.pathExtension.lowercased()
                            if ext == "key" {
                                DispatchQueue.main.async {
                                    dropAlertTitle = "Conversion Required"
                                    dropError = "Keynote files can't be imported directly. Please export your Keynote presentation as PowerPoint (.pptx) first, then drop the exported file here."
                                }
                                return
                            }
                            guard ext == "pptx" else {
                                DispatchQueue.main.async {
                                    dropAlertTitle = "Import Error"
                                    dropError = "Unsupported file. Drop a PowerPoint (.pptx) file."
                                }
                                return
                            }
                            DispatchQueue.main.async {
                                handlePresentationDrop(url: url)
                            }
                        }
                        return true
                    }
                    .allowsHitTesting(isDroppingPresentation)
            }
        }


    private var navSidebar: some View {
        VStack(spacing: 0) {
            sidebarActions
            sidebarDivider
            sidebarPagesHeader
            sidebarPageList
        }
        .frame(width: 180)
        .background(Color.primary.opacity(0.03))
    }

    private var sidebarActions: some View {
        VStack(spacing: 2) {
            homeButton
            sidebarButton(icon: "gearshape", label: "Settings") { showSettings = true }
            sidebarButton(icon: "books.vertical", label: "Library") { showLibrary = true }
            sidebarButton(icon: "waveform.and.mic", label: "Meetings") { showMeetingHistory = true }
            if NotchSettings.shared.coachingEnabled {
                sidebarButton(icon: "chart.bar", label: "Stats") { showSessionHistory = true }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var homeButton: some View {
        Button { showingHome = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "house")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showingHome ? .white : .secondary)
                    .frame(width: 18)
                Text("Home")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showingHome ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(showingHome ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    private var sidebarPagesHeader: some View {
        HStack {
            Text("PAGES")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .tracking(1)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    service.pages.append("")
                    service.currentPageIndex = service.pages.count - 1
                    showingHome = false
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private var sidebarPageList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Array(service.pages.enumerated()), id: \.offset) { index, page in
                    sidebarPageRow(index: index, page: page)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func sidebarPageRow(index: Int, page: String) -> some View {
        let isCurrent = service.currentPageIndex == index
        let isRead = service.readPages.contains(index)
        let preview = page.trimmingCharacters(in: .whitespacesAndNewlines)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                service.currentPageIndex = index
                showingHome = false
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isCurrent ? .white : .gray)
                    .frame(width: 16)
                Text(preview.isEmpty ? "Empty page" : String(preview.prefix(30)))
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .white : (preview.isEmpty ? .gray : .primary))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isRead && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCurrent ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if service.pages.count > 1 {
                Button(role: .destructive) {
                    removePage(at: index)
                } label: {
                    Label("Delete Page", systemImage: "trash")
                }
            }
        }
    }

    private func sidebarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func removePage(at index: Int) {
        guard service.pages.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            service.pages.remove(at: index)
            if service.currentPageIndex >= service.pages.count {
                service.currentPageIndex = service.pages.count - 1
            } else if service.currentPageIndex > index {
                service.currentPageIndex -= 1
            }
        }
    }

    private func run() {
        guard hasAnyContent else { return }
        // Resign text editor focus before hiding the window to avoid ViewBridge crashes
        isTextFocused = false
        service.onOverlayDismissed = { [self] in
            isRunning = false
            service.readPages.removeAll()

            // Show coaching report if enabled
            if NotchSettings.shared.showSessionReport,
               let session = service.overlayController.lastCompletedSession {
                completedSession = session
                service.overlayController.lastCompletedSession = nil
            }

            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        service.readPages.removeAll()
        service.currentPageIndex = 0
        service.readCurrentPage()
        isRunning = true
    }

    @State private var isImporting = false

    private func handlePresentationDrop(url: URL) {
        guard service.confirmDiscardIfNeeded() else { return }
        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let notes = try PresentationNotesExtractor.extractNotes(from: url)
                DispatchQueue.main.async {
                    service.pages = notes
                    service.savedPages = notes
                    service.currentPageIndex = 0
                    service.readPages.removeAll()
                    service.currentFileURL = nil
                    isImporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    dropError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func stop() {
        service.overlayController.dismiss()
        service.readPages.removeAll()
        isRunning = false
    }

    // MARK: - Meeting Setup Sheet

    private var meetingSetupSheet: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.orange)
                Text("Start a Meeting")
                    .font(.system(size: 20, weight: .bold))
                Text("SpeakCoach will listen and track your\nmetrics in real-time.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Form
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meeting Title")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Team Standup, 1:1 with Manager", text: $meetingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Talking Points")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("optional")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    TextEditor(text: $talkingPointsText)
                        .font(.system(size: 13))
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("One per line. Check them off during the meeting.")
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)

            // Actions
            HStack(spacing: 12) {
                Button {
                    showMeetingSetup = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button {
                    startMeeting()
                    showMeetingSetup = false
                } label: {
                    Text("Start Meeting")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 400)
        .background(.ultraThinMaterial)
    }

    private func startMeeting() {
        let title = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? "Meeting \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))" : title

        let points: [TalkingPoint] = talkingPointsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { TalkingPoint(text: $0) }

        isTextFocused = false
        isMeetingRunning = true

        service.meetingController.onComplete = { [self] record in
            isMeetingRunning = false
            completedMeeting = record
            meetingTitle = ""
            talkingPointsText = ""
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }

        service.meetingController.show(title: finalTitle, talkingPoints: points)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            // App icon
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            // App name & version
            VStack(spacing: 4) {
                Text("SpeakCoach")
                    .font(.system(size: 20, weight: .bold))
                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("A teleprompter with built-in speech coaching. Track your pace, filler words, and accuracy across every session.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Links
            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/abhitsian/speakcoach")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("GitHub")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            Divider().padding(.horizontal, 20)

            VStack(spacing: 4) {
                Text("Built by Vaibhav")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}

