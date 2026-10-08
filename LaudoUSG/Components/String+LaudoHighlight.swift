import SwiftUI

struct LaudoHighlightIssue: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case missing
        case warning
    }

    let id: String
    let kind: Kind
    let anchor: String?
    let message: String
    let severity: String
}

struct LaudoHighlightContent {
    let attributed: AttributedString
    let notices: [LaudoHighlightIssue]
}

extension LocalSanityIssue {
    var laudoHighlightIssue: LaudoHighlightIssue {
        LaudoHighlightIssue(
            id: code,
            kind: code.localizedCaseInsensitiveContains("placeholder") ? .missing : .warning,
            anchor: range,
            message: message,
            severity: severity
        )
    }
}

extension SanityIssue {
    var laudoHighlightIssue: LaudoHighlightIssue {
        let issueCode = code ?? "servidor"
        return LaudoHighlightIssue(
            id: issueCode,
            kind: issueCode.localizedCaseInsensitiveContains("placeholder") ? .missing : .warning,
            anchor: range,
            message: message,
            severity: severity ?? "warning"
        )
    }
}

extension String {
    private static let reviewMarker = try! Regex(#"\s*\[REVISAR\b[^\]]*\]"#)
    private static let placeholder = try! Regex(#"____|\{(?:LINHA|CONCLUSAO)_[A-Z_]+\}"#)

    var strippedReviewMarkers: String {
        replacing(String.reviewMarker, with: "")
    }

    var laudoHighlighted: AttributedString {
        laudoHighlight().attributed
    }

    func laudoHighlight(issues: [LaudoHighlightIssue] = []) -> LaudoHighlightContent {
        let cleanText = strippedReviewMarkers
        var candidates: [LaudoHighlightIssue] = []
        var notices: [LaudoHighlightIssue] = []
        var seen = Set<String>()

        for issue in issues {
            guard let rawAnchor = issue.anchor?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawAnchor.isEmpty,
                  let range = cleanText.range(of: rawAnchor, options: [.caseInsensitive, .diacriticInsensitive]) else {
                appendUnique(issue, to: &notices, seen: &seen)
                continue
            }
            let resolved = String(cleanText[range])
            let kind: LaudoHighlightIssue.Kind = resolved.firstMatch(of: String.placeholder) != nil ? .missing : issue.kind
            appendUnique(
                LaudoHighlightIssue(
                    id: issue.id,
                    kind: kind,
                    anchor: resolved,
                    message: issue.message,
                    severity: issue.severity
                ),
                to: &candidates,
                seen: &seen
            )
        }

        for match in cleanText.matches(of: String.placeholder) {
            let anchor = String(cleanText[match.range])
            guard !candidates.contains(where: { $0.kind == .missing && $0.anchor == anchor }) else {
                continue
            }
            let issue = LaudoHighlightIssue(
                id: "missing-\(cleanText.distance(from: cleanText.startIndex, to: match.range.lowerBound))",
                kind: .missing,
                anchor: anchor,
                message: "Informação pendente: preencha este trecho antes de finalizar o laudo.",
                severity: "critical"
            )
            appendUnique(issue, to: &candidates, seen: &seen)
        }

        var occurrences: [HighlightOccurrence] = []
        for issue in candidates {
            guard let anchor = issue.anchor, !anchor.isEmpty else { continue }
            var search = cleanText.startIndex..<cleanText.endIndex
            while let range = cleanText.range(of: anchor, options: [], range: search) {
                occurrences.append(HighlightOccurrence(range: range, issue: issue))
                guard range.upperBound < cleanText.endIndex else { break }
                search = range.upperBound..<cleanText.endIndex
            }
        }

        occurrences.sort {
            let left = cleanText.distance(from: cleanText.startIndex, to: $0.range.lowerBound)
            let right = cleanText.distance(from: cleanText.startIndex, to: $1.range.lowerBound)
            if left != right { return left < right }
            return $0.issue.kind == .missing && $1.issue.kind != .missing
        }

        var selected: [HighlightOccurrence] = []
        for candidate in occurrences {
            if selected.contains(where: { candidate.range.overlaps($0.range) }) { continue }
            selected.append(candidate)
        }

        var attributed = AttributedString("")
        var cursor = cleanText.startIndex
        for occurrence in selected {
            if cursor < occurrence.range.lowerBound {
                attributed.append(AttributedString(String(cleanText[cursor..<occurrence.range.lowerBound])))
            }
            var segment = AttributedString(String(cleanText[occurrence.range]))
            if occurrence.issue.kind == .missing {
                segment.backgroundColor = Color(hex: "EDE9FE")
                segment.foregroundColor = Color(hex: "6D28D9")
            } else {
                segment.backgroundColor = Color(hex: "FEF3C7")
                segment.foregroundColor = Color(hex: "92400E")
            }
            segment.link = LaudoHighlightLink.url(for: occurrence.issue)
            attributed.append(segment)
            cursor = occurrence.range.upperBound
        }
        if cursor < cleanText.endIndex {
            attributed.append(AttributedString(String(cleanText[cursor...])))
        }

        return LaudoHighlightContent(attributed: attributed, notices: notices)
    }

    private func appendUnique(
        _ issue: LaudoHighlightIssue,
        to target: inout [LaudoHighlightIssue],
        seen: inout Set<String>
    ) {
        let key = "\(issue.kind.rawValue)\u{0}\(issue.anchor ?? "")\u{0}\(issue.message)"
        guard seen.insert(key).inserted else { return }
        target.append(issue)
    }
}

private struct HighlightOccurrence {
    let range: Range<String.Index>
    let issue: LaudoHighlightIssue
}

private enum LaudoHighlightLink {
    static func url(for issue: LaudoHighlightIssue) -> URL? {
        var components = URLComponents()
        components.scheme = "laudousg-review"
        components.host = issue.kind.rawValue
        components.queryItems = [URLQueryItem(name: "message", value: issue.message)]
        return components.url
    }

    static func reason(from url: URL) -> (title: String, message: String)? {
        guard url.scheme == "laudousg-review",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let message = components.queryItems?.first(where: { $0.name == "message" })?.value else {
            return nil
        }
        let title = url.host == LaudoHighlightIssue.Kind.missing.rawValue
            ? "Informação pendente"
            : "Conferir este trecho"
        return (title, message)
    }
}

struct ReviewHighlightedText: View {
    let text: String
    var issues: [LaudoHighlightIssue] = []
    var selectionEnabled = true
    @State private var activeReason: ReviewReason?

    private var content: LaudoHighlightContent {
        text.laudoHighlight(issues: issues)
    }

    @ViewBuilder
    private var highlightedText: some View {
        if selectionEnabled {
            Text(content.attributed).textSelection(.enabled)
        } else {
            Text(content.attributed).textSelection(.disabled)
        }
    }

    var body: some View {
        highlightedText
            .environment(\.openURL, OpenURLAction { url in
                guard let reason = LaudoHighlightLink.reason(from: url) else { return .systemAction }
                activeReason = ReviewReason(title: reason.title, message: reason.message)
                return .handled
            })
            .alert(item: $activeReason) { reason in
                Alert(title: Text(reason.title), message: Text(reason.message), dismissButton: .default(Text("Entendi")))
            }
    }
}

struct GeneralReviewNoticesButton: View {
    let text: String
    var issues: [LaudoHighlightIssue] = []
    @State private var activeReason: ReviewReason?

    private var notices: [LaudoHighlightIssue] {
        text.laudoHighlight(issues: issues).notices
    }

    var body: some View {
        if !notices.isEmpty {
            Menu {
                ForEach(notices) { notice in
                    Button(notice.message) {
                        activeReason = ReviewReason(title: "Aviso geral", message: notice.message)
                    }
                }
            } label: {
                Label("\(notices.count)", systemImage: "exclamationmark.triangle.fill")
                    .font(TextStyle.captionMedium)
                    .foregroundStyle(SemanticColor.warningText)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 30)
                    .background(Capsule().fill(SemanticColor.warningBg))
                    .overlay(Capsule().stroke(SemanticColor.warningBorder, lineWidth: 1))
            }
            .alert(item: $activeReason) { reason in
                Alert(title: Text(reason.title), message: Text(reason.message), dismissButton: .default(Text("Entendi")))
            }
        }
    }
}

private struct ReviewReason: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
