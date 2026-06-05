# Complication da carátula — setup + código pronto

> O código abaixo está pronto. Falta só criar o **Widget Extension target** +
> **App Group** no Xcode (passos no fim). Não mexi no build atual pra não
> arriscar o que você vai testar agora.

## O que a complication mostra
- **Ditados pendentes** (gravados no watch, ainda não recuperados no iPhone) —
  o número que importa pra um glance no pulso.
- Famílias: circular, inline, retangular, canto.

## Como funciona (arquitetura)
O widget roda em **outro processo** → não enxerga a memória do app do watch.
Compartilhamento via **App Group** (`UserDefaults` compartilhado):
1. O app do watch escreve a contagem no App Group quando a fila muda.
2. Chama `WidgetCenter.shared.reloadAllTimelines()`.
3. O widget lê a contagem + redesenha.

---

## Passos no Xcode (~5 min)

1. **File → New → Target… → watchOS → Widget Extension**
   - Product Name: `LaudoUSGComplication`
   - Embed in: `LaudoUSGWatch`
   - **Desmarque** "Include Live Activity".
   - Finish → "Activate scheme" se perguntar.

2. **App Group nos 2 targets** (Signing & Capabilities → + Capability → App Groups):
   - No target **LaudoUSGWatch** e no **LaudoUSGComplication**, adicione o MESMO grupo:
     `group.com.laudousg.watch`

3. **Shared store nos 2 targets:** crie `WatchSharedStore.swift` (código abaixo) e
   marque **Target Membership** = LaudoUSGWatch **E** LaudoUSGComplication.

4. **Cole o código** do widget (abaixo) no arquivo gerado `LaudoUSGComplication.swift`.

5. Me avise — eu finalizo a fiação no `WatchSessionManager` (escrever a contagem +
   reload) e a gente testa.

---

## Código

### `WatchSharedStore.swift` (membership: watch app + complication)
```swift
import Foundation
import WidgetKit

/// Contagem compartilhada entre o app do Watch e a complication (App Group).
enum WatchSharedStore {
    static let appGroup = "group.com.laudousg.watch"
    private static let keyPending = "pendingDitados"
    private static let keySession = "sessionDitados"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func write(pending: Int, session: Int) {
        defaults?.set(pending, forKey: keyPending)
        defaults?.set(session, forKey: keySession)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> (pending: Int, session: Int) {
        let d = defaults
        return (d?.integer(forKey: keyPending) ?? 0, d?.integer(forKey: keySession) ?? 0)
    }
}
```

### `LaudoUSGComplication.swift` (target: LaudoUSGComplication)
```swift
import WidgetKit
import SwiftUI

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
        let s = WatchSharedStore.read()
        completion(DitadosEntry(date: Date(), pending: s.pending, session: s.session))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DitadosEntry>) -> Void) {
        let s = WatchSharedStore.read()
        let entry = DitadosEntry(date: Date(), pending: s.pending, session: s.session)
        completion(Timeline(entries: [entry], policy: .never))  // recarrega via reloadAllTimelines
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
                VStack(spacing: 0) {
                    Image(systemName: "waveform").font(.system(size: 11, weight: .semibold))
                    Text("\(entry.pending)").font(.system(size: 18, weight: .bold))
                }
            }
        case .accessoryInline:
            Label("\(entry.pending) ditado\(entry.pending == 1 ? "" : "s")", systemImage: "waveform")
        case .accessoryRectangular:
            HStack {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                VStack(alignment: .leading) {
                    Text("Ditados").font(.headline)
                    Text("\(entry.pending) pendente\(entry.pending == 1 ? "" : "s") · \(entry.session) na sessão")
                        .font(.caption)
                }
            }
        default:
            Text("\(entry.pending)").font(.system(size: 20, weight: .bold))
        }
    }
}

@main
struct LaudoUSGComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LaudoUSGDitados", provider: DitadosProvider()) { entry in
            DitadosComplicationView(entry: entry)
        }
        .configurationDisplayName("Ditados")
        .description("Ditados pendentes pra recuperar no iPhone.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}
```

### Fiação no `WatchSessionManager` (eu faço quando o target existir)
```swift
// no send() e no didFinish, após mudar a queue:
WatchSharedStore.write(pending: pendingCount, session: queue.count)
```
