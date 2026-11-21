import SwiftUI
import SchwipsCore

// MARK: Text

/// A fact that turns into a text field on double-click. Return or clicking
/// elsewhere saves, Escape restores the old value. `commit` returns the
/// message for a value the cellar refuses: the field then stays open with a
/// red outline and the message below it.
struct InlineTextField: View {
    var value: String
    /// What shows when not editing; the value when nil.
    var display: String?
    var font: Font = .callout
    var multiline = false
    var help: String
    var accessibilityName: String
    /// Raising it opens the field, for a button like Add Note….
    var editRequest = 0
    var commit: (String) -> String?

    @State private var isEditing = false
    @State private var text = ""
    @State private var error: String?
    @State private var isHovered = false
    @FocusState private var focused: Bool

    var body: some View {
        content
            .onChange(of: editRequest) { begin() }
    }

    @ViewBuilder private var content: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 3) {
                field
                    .textFieldStyle(.plain)
                    .font(font)
                    .focused($focused)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(error == nil ? Theme.accent : Theme.error, lineWidth: 2)
                    }
                    .onSubmit { finish() }
                    .onKeyPress(.escape) {
                        cancel()
                        return .handled
                    }
                    .onChange(of: focused) { _, now in
                        if !now { finish() }
                    }
                    .onChange(of: text) { error = nil }
                    .onAppear { focused = true }
                if let error {
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundStyle(Theme.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if !value.isEmpty || display != nil {
            Text(verbatim: display ?? value)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 3)
                .background {
                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(isHovered ? 0.06 : 0))
                }
                .padding(.horizontal, -3)
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .onTapGesture(count: 2) { begin() }
                .help(help)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(verbatim: accessibilityName))
                .accessibilityValue(Text(verbatim: display ?? value))
                .accessibilityAction { begin() }
        }
    }

    @ViewBuilder private var field: some View {
        if multiline {
            TextField(text: $text, axis: .vertical) { Text(verbatim: accessibilityName) }
                .lineLimit(3...12)
        } else {
            TextField(text: $text) { Text(verbatim: accessibilityName) }
        }
    }

    private func begin() {
        text = value
        error = nil
        isEditing = true
    }

    private func cancel() {
        error = nil
        isEditing = false
    }

    /// An invalid value keeps the field open, whether by Return or by
    /// clicking elsewhere; Escape restores.
    private func finish() {
        guard isEditing else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != value else {
            isEditing = false
            return
        }
        if let message = commit(trimmed) {
            error = message
            focused = true
            return
        }
        error = nil
        isEditing = false
    }
}

// MARK: Choice

/// A choice fact (type, colour, taste, closure): double-click opens a pop-up
/// with the values, plus "None" where the field may be empty.
struct InlineChoice: View {
    struct Option: Hashable {
        let raw: String
        let label: String
    }

    var current: String?
    var display: String
    var options: [Option]
    var allowsNone: Bool
    var help: String
    var accessibilityName: String
    var select: (String?) -> Void

    @State private var isOpen = false
    @State private var isHovered = false

    var body: some View {
        Text(verbatim: display)
            .font(.callout)
            .padding(.horizontal, 3)
            .background {
                RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(isHovered || isOpen ? 0.06 : 0))
            }
            .padding(.horizontal, -3)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(count: 2) { isOpen = true }
            .help(help)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(verbatim: accessibilityName))
            .accessibilityValue(Text(verbatim: display))
            .accessibilityAction { isOpen = true }
            .popover(isPresented: $isOpen, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        row(option.label, selected: option.raw == current) { select(option.raw) }
                    }
                    if allowsNone {
                        Divider().padding(.vertical, 4)
                        row(String(localized: "None", comment: "no value"), selected: current == nil) { select(nil) }
                    }
                }
                .padding(6)
                .frame(minWidth: 170)
            }
    }

    private func row(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            isOpen = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").opacity(selected ? 1 : 0)
                Text(verbatim: label)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
}
