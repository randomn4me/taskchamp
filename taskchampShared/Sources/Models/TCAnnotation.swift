import Foundation
import Taskchampion

/// A Taskwarrior annotation. Taskchampion identifies an annotation by its entry
/// timestamp (stored as `annotation_<unix seconds>`), so `entry` doubles as its id.
public struct TCAnnotation: Codable, Hashable, Identifiable {
    public static let obsidianNotePrefix = "task-note:"

    public let entry: Date
    public var description: String

    public init(entry: Date, description: String) {
        self.entry = entry
        self.description = description
    }

    @MainActor
    init?(from rustAnnotation: AnnotationRef) {
        guard let seconds = TimeInterval(rustAnnotation.get_entry().toString()) else {
            return nil
        }
        entry = Date(timeIntervalSince1970: seconds)
        description = rustAnnotation.get_description().toString()
    }

    public var id: String {
        entrySeconds
    }

    /// The entry as whole unix seconds, the format the Rust bridge expects.
    public var entrySeconds: String {
        String(Int(entry.timeIntervalSince1970.rounded()))
    }

    /// Annotations used by the Obsidian integration to link a task to its note.
    public var isObsidianNote: Bool {
        description.starts(with: Self.obsidianNotePrefix)
    }

    public var localEntryDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: entry)
    }
}
