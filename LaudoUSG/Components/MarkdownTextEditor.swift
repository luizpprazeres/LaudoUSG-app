import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MarkdownEditorBridge: ObservableObject {
    fileprivate weak var textView: UITextView?

    func wrap(prefix: String, suffix: String? = nil) {
        guard let textView else { return }
        let actualSuffix = suffix ?? prefix
        let nsText = textView.text as NSString
        let range = textView.selectedRange

        let before = nsText.substring(to: range.location)
        let selected = nsText.substring(with: range)
        let after = nsText.substring(from: range.location + range.length)

        if range.length == 0 {
            let cursorText = "\(prefix)\(actualSuffix)"
            textView.text = before + cursorText + after
            let newPosition = range.location + (prefix as NSString).length
            textView.selectedRange = NSRange(location: newPosition, length: 0)
        } else {
            let wrappedText = "\(prefix)\(selected)\(actualSuffix)"
            textView.text = before + wrappedText + after
            let newLocation = range.location + (prefix as NSString).length
            textView.selectedRange = NSRange(location: newLocation, length: (selected as NSString).length)
        }
        textView.delegate?.textViewDidChange?(textView)
    }

    func replaceAllText(_ newText: String) {
        guard let textView else { return }
        textView.text = newText
        textView.delegate?.textViewDidChange?(textView)
    }

    func focus() {
        textView?.becomeFirstResponder()
    }

    func blur() {
        textView?.resignFirstResponder()
    }
}

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    let bridge: MarkdownEditorBridge
    var font: UIFont = .preferredFont(forTextStyle: .body).withSize(16)
    var textColor: UIColor = .label
    var backgroundColor: UIColor = .clear

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isEditable = true
        view.isScrollEnabled = true
        view.font = font
        view.textColor = textColor
        view.backgroundColor = backgroundColor
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.autocorrectionType = .yes
        view.autocapitalizationType = .sentences
        view.keyboardDismissMode = .interactive
        view.text = text
        bridge.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            let prevRange = view.selectedRange
            view.text = text
            let newLength = (view.text as NSString).length
            view.selectedRange = NSRange(
                location: min(prevRange.location, newLength),
                length: 0
            )
        }
        if view.font != font { view.font = font }
        if view.textColor != textColor { view.textColor = textColor }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            Task { @MainActor in
                parent.text = textView.text
            }
        }
    }
}
