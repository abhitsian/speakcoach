//
//  SpeakCoachService.swift
//  SpeakCoach
//
//
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

class SpeakCoachService: NSObject, ObservableObject {
    static let shared = SpeakCoachService()
    let overlayController = NotchOverlayController()
    let externalDisplayController = ExternalDisplayController()
    let browserServer = BrowserServer()
    let meetingController = MeetingOverlayController()
    var onOverlayDismissed: (() -> Void)?
    var launchedExternally = false

    override init() {
        super.init()
        loadPersistedPages()
    }

    @Published var pages: [String] = [""] {
        didSet { persistPages() }
    }
    @Published var currentPageIndex: Int = 0
    @Published var readPages: Set<Int> = []

    private func persistPages() {
        if let data = try? JSONEncoder().encode(pages) {
            UserDefaults.standard.set(data, forKey: "speakcoach.pages")
        }
    }

    private func loadPersistedPages() {
        if let data = UserDefaults.standard.data(forKey: "speakcoach.pages"),
           let saved = try? JSONDecoder().decode([String].self, from: data),
           !saved.isEmpty {
            pages = saved
        }
    }

    var hasNextPage: Bool {
        for i in (currentPageIndex + 1)..<pages.count {
            if !pages[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    var currentPageText: String {
        guard currentPageIndex < pages.count else { return "" }
        return pages[currentPageIndex]
    }

    func readText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        launchedExternally = true
        hideMainWindow()

        overlayController.show(text: trimmed, hasNextPage: hasNextPage) { [weak self] in
            self?.externalDisplayController.dismiss()
            self?.browserServer.hideContent()
            self?.onOverlayDismissed?()
        }
        updatePageInfo()

        // Also show on external display if configured (same parsing as overlay)
        let words = splitTextIntoWords(trimmed)
        let totalCharCount = words.joined(separator: " ").count
        externalDisplayController.show(
            speechRecognizer: overlayController.speechRecognizer,
            words: words,
            totalCharCount: totalCharCount,
            hasNextPage: hasNextPage
        )

        if browserServer.isRunning {
            browserServer.showContent(
                speechRecognizer: overlayController.speechRecognizer,
                words: words,
                totalCharCount: totalCharCount,
                hasNextPage: hasNextPage
            )
        }
    }

    func readCurrentPage() {
        let trimmed = currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        readPages.insert(currentPageIndex)
        readText(trimmed)
    }

    func advanceToNextPage() {
        // Skip empty pages
        var nextIndex = currentPageIndex + 1
        while nextIndex < pages.count {
            let text = pages[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { break }
            nextIndex += 1
        }
        guard nextIndex < pages.count else { return }
        jumpToPage(index: nextIndex)
    }

    func jumpToPage(index: Int) {
        guard index >= 0 && index < pages.count else { return }
        let text = pages[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Mute mic before switching page content
        let wasListening = overlayController.speechRecognizer.isListening
        if wasListening {
            overlayController.speechRecognizer.stop()
        }

        currentPageIndex = index
        readPages.insert(currentPageIndex)

        let trimmed = currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Update content in-place without recreating the panel
        overlayController.updateContent(text: trimmed, hasNextPage: hasNextPage)
        updatePageInfo()

        // Also update external display content in-place
        let words = splitTextIntoWords(trimmed)
        externalDisplayController.overlayContent.words = words
        externalDisplayController.overlayContent.totalCharCount = words.joined(separator: " ").count
        externalDisplayController.overlayContent.hasNextPage = hasNextPage

        if browserServer.isRunning {
            browserServer.updateContent(
                words: words,
                totalCharCount: words.joined(separator: " ").count,
                hasNextPage: hasNextPage
            )
        }

        // Unmute after new page content is loaded
        if wasListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.overlayController.speechRecognizer.resume()
            }
        }
    }

    func updatePageInfo() {
        let content = overlayController.overlayContent
        content.pageCount = pages.count
        content.currentPageIndex = currentPageIndex
        content.pagePreviews = pages.enumerated().map { (i, text) in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            let preview = String(trimmed.prefix(40))
            return preview + (trimmed.count > 40 ? "…" : "")
        }
    }

    func startAllPages() {
        readPages.removeAll()
        currentPageIndex = 0
        readCurrentPage()
    }

    func hideMainWindow() {
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeFirstResponder(nil)
                window.orderOut(nil)
            }
        }
    }

    @Published var currentFileURL: URL?
    @Published var savedPages: [String] = [""]

    // MARK: - File Operations

    func saveFile() {
        if let url = currentFileURL {
            saveToURL(url)
        } else {
            saveFileAs()
        }
    }

    func saveFileAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "speakcoach")!]
        panel.nameFieldStringValue = "Untitled.speakcoach"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveToURL(url)
        }
    }

    private func saveToURL(_ url: URL) {
        do {
            let data = try JSONEncoder().encode(pages)
            try data.write(to: url, options: .atomic)
            currentFileURL = url
            savedPages = pages
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to save file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    var hasUnsavedChanges: Bool {
        pages != savedPages
    }

    func openFile() {
        guard confirmDiscardIfNeeded() else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "speakcoach")!,
            .init(filenameExtension: "key")!,
            .init(filenameExtension: "pptx")!,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let ext = url.pathExtension.lowercased()
            if ext == "key" {
                let alert = NSAlert()
                alert.messageText = "Keynote files can't be imported directly"
                alert.informativeText = "Please export your Keynote presentation as PowerPoint (.pptx) first:\n\nIn Keynote: File → Export To → PowerPoint"
                alert.alertStyle = .informational
                alert.runModal()
            } else if ext == "pptx" {
                self?.importPresentation(from: url)
            } else {
                self?.openFileAtURL(url)
            }
        }
    }

    func importPresentation(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let notes = try PresentationNotesExtractor.extractNotes(from: url)
                DispatchQueue.main.async {
                    self?.pages = notes
                    self?.savedPages = notes
                    self?.currentPageIndex = 0
                    self?.readPages.removeAll()
                    self?.currentFileURL = nil
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Import Error"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    /// Returns true if it's safe to proceed (saved, discarded, or no changes).
    /// Returns false if the user cancelled.
    func confirmDiscardIfNeeded() -> Bool {
        guard hasUnsavedChanges else { return true }

        let alert = NSAlert()
        alert.messageText = "You have unsaved changes"
        alert.informativeText = "Do you want to save your changes before opening another file?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            saveFile()
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func openFileAtURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let loadedPages = try JSONDecoder().decode([String].self, from: data)
            guard !loadedPages.isEmpty else { return }
            pages = loadedPages
            savedPages = loadedPages
            currentPageIndex = 0
            readPages.removeAll()
            currentFileURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to open file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Script Library

    func saveToLibrary() {
        guard hasAnyContent else { return }

        let alert = NSAlert()
        alert.messageText = "Save to Library"
        alert.informativeText = "Enter a name for this script:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.placeholderString = "My Script"
        // Default title from file name or first line
        if let url = currentFileURL {
            textField.stringValue = url.deletingPathExtension().lastPathComponent
        } else {
            let firstLine = pages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            textField.stringValue = String(trimmed.prefix(40))
        }
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let nonEmptyPages = pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        ScriptLibrary.shared.add(title: title, pages: nonEmptyPages.isEmpty ? pages : nonEmptyPages)
    }

    func loadFromLibrary(_ script: SavedScript) {
        guard confirmDiscardIfNeeded() else { return }
        pages = script.pages
        savedPages = script.pages
        currentPageIndex = 0
        readPages.removeAll()
        currentFileURL = nil
    }

    private var hasAnyContent: Bool {
        pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Browser Server

    func updateBrowserServer() {
        if NotchSettings.shared.browserServerEnabled {
            if !browserServer.isRunning {
                browserServer.start()
            }
        } else {
            browserServer.stop()
        }
    }

    // macOS Services handler
    @objc func readInSpeakCoach(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            return
        }
        readText(text)
    }

    // URL scheme handler: speakcoach://read?text=Hello%20World
    func handleURL(_ url: URL) {
        guard url.scheme == "speakcoach" else { return }

        if url.host == "read" || url.path == "/read" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let textParam = components.queryItems?.first(where: { $0.name == "text" })?.value {
                readText(textParam)
            }
        }
    }
}
