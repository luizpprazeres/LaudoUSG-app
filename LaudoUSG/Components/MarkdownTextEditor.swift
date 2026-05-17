import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MarkdownEditorBridge: ObservableObject {
    fileprivate weak var textView: UITextView?
    fileprivate var defaultFont: UIFont = .preferredFont(forTextStyle: .body).withSize(16)
    fileprivate var defaultColor: UIColor = .label

    func toggleBold() {
        applyTrait(.traitBold)
    }

    func toggleItalic() {
        applyTrait(.traitItalic)
    }

    func replaceAllText(_ markdown: String) {
        guard let textView else { return }
        let attributed = AttributedMarkdown.parse(markdown, font: defaultFont, color: defaultColor)
        textView.attributedText = attributed
        textView.delegate?.textViewDidChange?(textView)
    }

    func focus() { textView?.becomeFirstResponder() }
    func blur() { textView?.resignFirstResponder() }

    private func applyTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let textView else { return }
        let range = textView.selectedRange

        if range.length == 0 {
            var typing = textView.typingAttributes
            let currentFont = (typing[.font] as? UIFont) ?? defaultFont
            typing[.font] = toggling(font: currentFont, trait: trait)
            if typing[.foregroundColor] == nil {
                typing[.foregroundColor] = defaultColor
            }
            textView.typingAttributes = typing
            return
        }

        let mutable = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        let allHaveTrait = rangeHasTraitUniformly(mutable, range: range, trait: trait)

        mutable.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let baseFont = (value as? UIFont) ?? defaultFont
            let newFont: UIFont
            if allHaveTrait {
                newFont = removing(trait: trait, from: baseFont)
            } else {
                newFont = adding(trait: trait, to: baseFont)
            }
            mutable.addAttribute(.font, value: newFont, range: subRange)
        }

        textView.attributedText = mutable
        textView.selectedRange = range
        textView.delegate?.textViewDidChange?(textView)
    }

    private func rangeHasTraitUniformly(_ attributed: NSAttributedString, range: NSRange, trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        var uniform = true
        attributed.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            let font = (value as? UIFont) ?? defaultFont
            if !font.fontDescriptor.symbolicTraits.contains(trait) {
                uniform = false
                stop.pointee = true
            }
        }
        return uniform
    }

    private func toggling(font: UIFont, trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private func adding(trait: UIFontDescriptor.SymbolicTraits, to font: UIFont) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(trait)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private func removing(trait: UIFontDescriptor.SymbolicTraits, from font: UIFont) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.remove(trait)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

enum AttributedMarkdown {
    static func parse(_ markdown: String, font: UIFont, color: UIColor) -> NSAttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.allowsExtendedAttributes = true

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown, attributes: baseAttributes)
        }

        let nsAttributed = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        let fullRange = NSRange(location: 0, length: nsAttributed.length)

        nsAttributed.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            var newFont = font
            if let intent = attrs[.init("NSInlinePresentationIntent")] as? Int {
                let isBold = (intent & 1) != 0
                let isItalic = (intent & 2) != 0
                if isBold || isItalic {
                    var traits = font.fontDescriptor.symbolicTraits
                    if isBold { traits.insert(.traitBold) }
                    if isItalic { traits.insert(.traitItalic) }
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    }
                }
            }
            nsAttributed.addAttribute(.font, value: newFont, range: range)
            nsAttributed.addAttribute(.foregroundColor, value: color, range: range)
        }

        return nsAttributed
    }

    static func serialize(_ attributed: NSAttributedString) -> String {
        let raw = attributed.string as NSString
        var output = ""
        var index = 0
        let total = attributed.length

        while index < total {
            var effectiveRange = NSRange(location: 0, length: 0)
            let font = (attributed.attribute(.font, at: index, effectiveRange: &effectiveRange) as? UIFont)
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let isBold = traits.contains(.traitBold)
            let isItalic = traits.contains(.traitItalic)

            let endExclusive = min(effectiveRange.location + effectiveRange.length, total)
            let snippet = raw.substring(with: NSRange(location: index, length: endExclusive - index))
            output += wrap(snippet, bold: isBold, italic: isItalic)
            index = endExclusive
        }

        return output
    }

    private static func wrap(_ text: String, bold: Bool, italic: Bool) -> String {
        guard !text.isEmpty else { return text }
        // Não envolva apenas whitespace/newlines — gera markdown estranho.
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        let marker: String
        switch (bold, italic) {
        case (true, true): marker = "***"
        case (true, false): marker = "**"
        case (false, true): marker = "*"
        case (false, false): return text
        }

        let leadingCount = text.prefix(while: { $0.isWhitespace || $0.isNewline }).count
        let trailingCount = text.reversed().prefix(while: { $0.isWhitespace || $0.isNewline }).count
        let startIdx = text.index(text.startIndex, offsetBy: leadingCount)
        let endIdx = text.index(text.endIndex, offsetBy: -trailingCount)
        let leading = String(text[text.startIndex..<startIdx])
        let core = String(text[startIdx..<endIdx])
        let trailing = String(text[endIdx..<text.endIndex])
        if core.isEmpty { return text }
        return "\(leading)\(marker)\(core)\(marker)\(trailing)"
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
        view.backgroundColor = backgroundColor
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.autocorrectionType = .yes
        view.autocapitalizationType = .sentences
        view.keyboardDismissMode = .interactive

        view.attributedText = AttributedMarkdown.parse(text, font: font, color: textColor)
        view.typingAttributes = [.font: font, .foregroundColor: textColor]

        bridge.textView = view
        bridge.defaultFont = font
        bridge.defaultColor = textColor
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let currentSerialized = AttributedMarkdown.serialize(view.attributedText ?? NSAttributedString())
        if currentSerialized != text {
            let attributed = AttributedMarkdown.parse(text, font: font, color: textColor)
            let prevRange = view.selectedRange
            view.attributedText = attributed
            let newLength = (view.attributedText?.length ?? 0)
            view.selectedRange = NSRange(
                location: min(prevRange.location, newLength),
                length: 0
            )
        }
        bridge.defaultFont = font
        bridge.defaultColor = textColor
        view.typingAttributes = mergedTypingAttributes(view.typingAttributes)
    }

    private func mergedTypingAttributes(_ current: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var merged = current
        if merged[.foregroundColor] == nil { merged[.foregroundColor] = textColor }
        if merged[.font] == nil { merged[.font] = font }
        return merged
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let serialized = AttributedMarkdown.serialize(textView.attributedText ?? NSAttributedString())
            Task { @MainActor in
                if parent.text != serialized {
                    parent.text = serialized
                }
            }
        }
    }
}
