import SwiftUI
import taskchampShared

/// What the annotation editor sheet is working on.
enum AnnotationEditorTarget: Identifiable {
    case new
    case existing(TCAnnotation)

    var id: String {
        switch self {
        case .new:
            return "new"
        case let .existing(annotation):
            return annotation.id
        }
    }

    var annotation: TCAnnotation? {
        if case let .existing(annotation) = self {
            return annotation
        }
        return nil
    }
}

struct AnnotationEditorView: View {
    @Environment(\.dismiss) var dismiss

    let target: AnnotationEditorTarget
    let onSave: (String) -> Void
    let onDelete: (() -> Void)?

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        target: AnnotationEditorTarget,
        onSave: @escaping (String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.target = target
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: target.annotation?.description ?? "")
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedText.isEmpty && trimmedText != target.annotation?.description
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(minHeight: 120)
            } footer: {
                if let annotation = target.annotation {
                    Text("Added \(annotation.localEntryDate)")
                }
            }
            if let onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete annotation", systemImage: SFSymbols.trash.rawValue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .navigationTitle(target.annotation == nil ? "New annotation" : "Edit annotation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(trimmedText)
                    dismiss()
                }
                .bold()
                .disabled(!canSave)
                .tint(Color(asset: TaskchampAsset.Assets.accentColor))
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}
