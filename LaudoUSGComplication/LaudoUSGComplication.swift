import WidgetKit
import SwiftUI

/// Lê a contagem compartilhada pelo app do Watch (App Group). O widget roda em
/// outro processo, por isso a troca é via UserDefaults compartilhado.
private enum SharedStore {
    static let appGroup = "group.com.laudousg.watch"
    static func read() -> (pending: Int, session: Int) {
        let d = UserDefaults(suiteName: appGroup)
        return (d?.integer(forKey: "pendingDitados") ?? 0,
                d?.integer(forKey: "sessionDitados") ?? 0)
    }
}

struct DitadosEntry: TimelineEntry {
    let date: Date
    let pending: Int
    let session: Int
}

struct DitadosProvider: TimelineProvider {
    func placeholder(in context: Context) -> DitadosEntry {
        DitadosEntry(date: Date(), pending: 0, session: 0)
    }
    func getSnapshot(in context: Context, completion: @escaping (DitadosEntry) -> Void) {
        let s = SharedStore.read()
        completion(DitadosEntry(date: Date(), pending: s.pending, session: s.session))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DitadosEntry>) -> Void) {
        let s = SharedStore.read()
        // Recarregado sob demanda pelo app (reloadTimelines). O .after é só rede
        // de segurança caso o reload do app não chegue.
        let entry = DitadosEntry(date: Date(), pending: s.pending, session: s.session)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct DitadosComplicationView: View {
    @Environment(\.widgetFamily) var family
    var entry: DitadosEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if entry.pending == 0 {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    VStack(spacing: 0) {
                        Image(systemName: "waveform").font(.system(size: 11, weight: .semibold))
                        Text("\(entry.pending)").font(.system(size: 18, weight: .bold))
                    }
                }
            }
        case .accessoryInline:
            if entry.pending == 0 {
                Label("LaudoUSG", systemImage: "applewatch.radiowaves.left.and.right")
            } else {
                Label("\(entry.pending) ditado\(entry.pending == 1 ? "" : "s")", systemImage: "waveform")
            }
        case .accessoryRectangular:
            HStack {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Ditados").font(.headline)
                    Text(entry.pending == 0
                         ? "Nenhum pendente"
                         : "\(entry.pending) pendente\(entry.pending == 1 ? "" : "s") · \(entry.session) na sessão")
                        .font(.caption)
                }
            }
        default:
            if entry.pending == 0 {
                Image(systemName: "applewatch.radiowaves.left.and.right").font(.system(size: 18, weight: .semibold))
            } else {
                Text("\(entry.pending)").font(.system(size: 20, weight: .bold))
            }
        }
    }
}

struct LaudoUSGComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LaudoUSGDitados", provider: DitadosProvider()) { entry in
            DitadosComplicationView(entry: entry)
        }
        .configurationDisplayName("Ditados")
        .description("Ditados pendentes pra recuperar no iPhone.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
