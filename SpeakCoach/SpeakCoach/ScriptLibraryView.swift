//
//  ScriptLibraryView.swift
//  SpeakCoach
//
//  In-app script library browser — modern, card-based design.
//

import SwiftUI

struct ScriptLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var deleteTarget: SavedScript?
    var onOpen: (SavedScript) -> Void

    private var library: ScriptLibrary { ScriptLibrary.shared }

    private var filteredScripts: [SavedScript] {
        let sorted = library.scripts.sorted { $0.lastModifiedDate > $1.lastModifiedDate }
        if searchText.isEmpty { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.title.lowercased().contains(query) ||
            $0.pages.joined(separator: " ").lowercased().contains(query)
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
                    Text("Script Library")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    if !library.scripts.isEmpty {
                        Text("\(library.scripts.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search scripts...", text: $searchText)
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

            // Script list
            if filteredScripts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: library.scripts.isEmpty ? "doc.text" : "magnifyingglass")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text(library.scripts.isEmpty
                         ? "No saved scripts"
                         : "No matching scripts")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if library.scripts.isEmpty {
                        Text("Save a script from the File menu\nor use Cmd+Shift+L.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredScripts) { script in
                            scriptCard(script)
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
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
        .alert("Delete Script?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let script = deleteTarget {
                    withAnimation { library.delete(id: script.id) }
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let script = deleteTarget {
                Text("\"\(script.title)\" will be permanently deleted.")
            }
        }
    }

    private func scriptCard(_ script: SavedScript) -> some View {
        Button {
            onOpen(script)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if renamingID == script.id {
                        TextField("Title", text: $renameText, onCommit: {
                            let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                library.rename(id: script.id, to: trimmed)
                            }
                            renamingID = nil
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text(script.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }

                if !script.snippet.isEmpty {
                    Text(script.snippet)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc")
                            .font(.system(size: 9))
                        Text("\(script.pageCount) \(script.pageCount == 1 ? "page" : "pages")")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(Self.dateFormatter.string(from: script.lastModifiedDate))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renamingID = script.id
                renameText = script.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                deleteTarget = script
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
