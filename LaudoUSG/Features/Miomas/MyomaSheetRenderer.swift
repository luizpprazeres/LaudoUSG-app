import UIKit

/// Um mioma na folha, na ordem em que o laudo o descreve (M1, M2…).
struct MyomaSheetItem: Equatable {
    var figo: Int?
    var location: MyomaLocation
    /// Eixos em mm (1 a 3). A legenda mostra todos; o desenho usa o maior.
    var dimsMm: [Double]
    var calcified: Bool

    var maxMm: Double { dimsMm.max() ?? 20 }
}

extension MyomaSheetItem {
    init(_ f: MyomaFinding) {
        let dims = f.dimsMm ?? []
        // Medida editada à mão (maior eixo) vence os eixos lidos do laudo quando não batem.
        let usarEixos = !dims.isEmpty && (f.sizeMaxMm == nil || abs((dims.max() ?? 0) - (f.sizeMaxMm ?? 0)) < 0.05)
        self.init(
            figo: f.figo,
            location: f.localizacao,
            dimsMm: usarEixos ? dims : (f.sizeMaxMm.map { [$0] } ?? []),
            calcified: f.ecotextura == .calcificada
        )
    }
}

/// Geometria das artes (gerada no Mac por `exportar-geometria.swift`, mesmo algoritmo do protótipo):
/// centro da cavidade, direções das paredes, escala e, por ângulo (passo de 0,5°), a distância até o
/// endométrio (1ª linha) e até a serosa (última linha). Assim o app não varre pixels.
struct MyomaArtGeometry: Decodable {
    struct Vista: Decodable {
        let largura: Double
        let altura: Double
        let centro: [Double]
        let colo: [Double]
        let direcoes: [String: [Double]]
        let pxPorMm: Double
        let conteudo: [Double]
        let endometrio: [Double]
        let serosa: [Double]

        /// Distâncias (em px da arte) do centro até o endométrio e até a serosa na direção dada.
        func cruzamentos(_ d: CGVector) -> (endometrio: CGFloat?, serosa: CGFloat?) {
            var a = atan2(d.dy, d.dx)
            if a < 0 { a += 2 * .pi }
            let i = Int((a / .pi * 360).rounded()) % endometrio.count
            let e = endometrio[i], s = serosa[i]
            return (e < 0 ? nil : CGFloat(e), s < 0 ? nil : CGFloat(s))
        }
    }
    struct Desenho: Decodable {
        /// Diâmetro do mioma em fração do quadro do desenho.
        let diametro: Double
        /// Centro do mioma e ponta de cima, em fração do quadro a partir do centro (y para baixo).
        let centroY: Double
        let topo: Double
    }
    let vistas: [String: Vista]
    let miomas: [String: Desenho]

    static let shared: MyomaArtGeometry? = {
        guard let url = Bundle.main.url(forResource: "myoma-art-geometry", withExtension: "json", subdirectory: "Miomas")
                ?? Bundle.main.url(forResource: "myoma-art-geometry", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MyomaArtGeometry.self, from: data)
    }()
}

/// Folha A4 (retrato, 300 dpi) do esquema de miomas: vista frontal em cima, longitudinal e transversal
/// embaixo, todas com os mesmos miomas (M1, M2…), e a legenda com FIGO, eixos, tipo e parede.
/// Porta do protótipo aprovado pelo Dr. Luiz (`tmp-review/miomas-arte/compor.swift` + `a4.swift`).
enum MyomaSheetRenderer {
    static let pageSize = CGSize(width: 2480, height: 3508)
    private static let margem: CGFloat = 213   // 18 mm
    private static let fonteRotulo: CGFloat = 44

    enum Vista: String, CaseIterable {
        case coronal, longitudinal, transversal
        var imagem: String {
            switch self {
            case .coronal: return "MyomaArtCoronal"
            case .longitudinal: return "MyomaArtLongitudinal"
            case .transversal: return "MyomaArtTransversal"
            }
        }
    }

    // MARK: - API

    /// Folha inteira. `scale` < 1 gera uma prévia mais leve com o mesmo desenho.
    static func render(_ itens: [MyomaSheetItem], scale: CGFloat = 1) -> UIImage? {
        guard let geo = MyomaArtGeometry.shared else { return nil }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: pageSize, format: fmt).image { rc in
            desenharFolha(rc.cgContext, itens, geo)
        }
    }

    /// PDF A4 retrato com a folha ocupando a página (as margens já estão no desenho).
    static func renderPDF(_ itens: [MyomaSheetItem]) -> Data? {
        guard let img = render(itens) else { return nil }
        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [
            kCGPDFContextCreator as String: "LaudoUSG",
            kCGPDFContextTitle as String: "Mapa de miomas uterinos (FIGO)",
        ]
        let pagina = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        return UIGraphicsPDFRenderer(bounds: pagina, format: fmt).pdfData { ctx in
            ctx.beginPage()
            img.draw(in: pagina)
        }
    }

    // MARK: - Posição de cada mioma numa vista (coordenadas da arte, y para baixo)

    struct Posicionado {
        let n: Int
        let item: MyomaSheetItem
        let desenho: String
        let centro: CGPoint        // centro do mioma
        let r: CGFloat             // raio do mioma
        let centroDesenho: CGPoint // centro do quadro do desenho
        let lado: CGFloat          // lado do quadro do desenho
        let angulo: CGFloat
        let corteTopo: CGFloat?    // pedículo longo: mostra só a partir daqui (y local, para baixo)
        let caixa: CGRect          // o que o desenho ocupa (para enquadrar e para os rótulos)
    }

    private static func chave(_ l: MyomaLocation) -> String {
        switch l {
        case .anterior: return "anterior"
        case .posterior: return "posterior"
        case .lateralDireita: return "lateral_dir"
        case .lateralEsquerda: return "lateral_esq"
        case .fundo, .notInformed, .cervical: return "fundo"
        }
    }

    static func posicionar(_ vista: Vista, _ itens: [MyomaSheetItem], _ geo: MyomaArtGeometry) -> [Posicionado] {
        guard let g = geo.vistas[vista.rawValue] else { return [] }
        let W = CGFloat(g.largura), H = CGFloat(g.altura)
        let C = CGPoint(x: CGFloat(g.centro[0]) * W, y: CGFloat(g.centro[1]) * H)
        let pxPorMm = CGFloat(g.pxPorMm)
        let leque: [CGFloat] = [0, 0.38, -0.38, 0.76, -0.76, 1.1, -1.1]
        let pad: CGFloat = 0.15
        func dentro(_ c: CGPoint, _ r: CGFloat) -> CGPoint {
            CGPoint(x: min(max(c.x, -W * pad + r + 8), W * (1 + pad) - r - 8),
                    y: min(max(c.y, -H * pad + r + 40), H * (1 + pad) - r - 8))
        }
        func vetor(_ v: [Double]) -> CGVector { CGVector(dx: CGFloat(v[0]), dy: CGFloat(v[1])) }

        var usados: [String: Int] = [:]
        var out: [Posicionado] = []
        let ordem = itens.enumerated().sorted { $0.element.maxMm > $1.element.maxMm }   // maiores primeiro, por baixo
        for (i, m) in ordem {
            let figo = m.figo ?? (m.location == .cervical ? 8 : 4)
            if vista == .transversal && figo == 8 { continue }   // o corte transversal é do corpo; o colo não aparece
            var loc = chave(m.location)
            if vista == .longitudinal, loc.hasPrefix("lateral") { loc = loc == "lateral_dir" ? "anterior" : "posterior" }
            let d0 = figo == 8 ? CGVector(dx: 0, dy: 1) : vetor(g.direcoes[loc] ?? g.direcoes["fundo"]!)
            let k = usados[loc, default: 0]; usados[loc] = k + 1
            let a = figo == 8 ? 0 : leque[min(k, leque.count - 1)]
            let d = CGVector(dx: d0.dx * cos(a) - d0.dy * sin(a), dy: d0.dx * sin(a) + d0.dy * cos(a))
            let cr = g.cruzamentos(d)
            let dE = cr.endometrio ?? 40, dS = cr.serosa ?? W * 0.3
            let r = CGFloat(m.maxMm) * pxPorMm / 2
            let t: CGFloat
            switch figo {
            case 0: t = dE * 0.2
            case 1: t = dE + r * 0.25
            case 2: t = dE + r * 0.6
            case 3: t = dE + r
            case 4: t = (dE + dS) / 2
            case 5: t = dS - r * 0.35
            case 6: t = dS + r * 0.25
            case 7: t = dS + r * 1.9
            default: t = 0
            }
            let nome = m.calcified ? "calcificado" : (figo == 0 || figo == 7) ? "pediculado" : (figo <= 2 ? "submucoso" : "intramural")
            guard let med = geo.miomas[nome] else { continue }
            let lado = r * 2 / CGFloat(med.diametro)
            var centro = figo == 8
                ? CGPoint(x: CGFloat(g.colo[0]) * W, y: CGFloat(g.colo[1]) * H)
                : CGPoint(x: C.x + d.dx * t, y: C.y + d.dy * t)
            centro = dentro(centro, r)
            var centroDesenho = centro
            var ang: CGFloat = 0
            var corte: CGFloat?
            if nome == "submucoso" || nome == "pediculado" {
                // face achatada / pedículo para a cavidade; no FIGO 0 o pedículo vai para a parede
                ang = figo == 0 ? atan2(d.dy, d.dx) + .pi / 2 : atan2(-d.dy, -d.dx) + .pi / 2
            }
            if nome == "calcificado" {
                // o centro do quadro fica abaixo do corpo (arco em cima, sombra embaixo); sombra sempre para baixo
                centroDesenho = CGPoint(x: centro.x, y: centro.y - CGFloat(med.centroY) * lado)
            }
            var pontaPediculo: CGPoint?
            if nome == "pediculado" {
                // pedículo natural do desenho; se for longo, mostra só um trecho curto, junto da borda do útero
                let natural = CGFloat(med.centroY - med.diametro / 2 - med.topo) * lado
                let L = min(natural, r * 0.35)
                let ateCentro = L + r
                if figo == 0 {
                    let dist = max(4, dE * 0.9 - ateCentro)
                    centro = dentro(CGPoint(x: C.x + d.dx * dist, y: C.y + d.dy * dist), r)
                    centroDesenho = CGPoint(x: centro.x + d.dx * CGFloat(med.centroY) * lado, y: centro.y + d.dy * CGFloat(med.centroY) * lado)
                    pontaPediculo = CGPoint(x: centro.x + d.dx * ateCentro, y: centro.y + d.dy * ateCentro)
                } else {
                    let dist = dS + ateCentro
                    centro = dentro(CGPoint(x: C.x + d.dx * dist, y: C.y + d.dy * dist), r)
                    centroDesenho = CGPoint(x: centro.x - d.dx * CGFloat(med.centroY) * lado, y: centro.y - d.dy * CGFloat(med.centroY) * lado)
                    pontaPediculo = CGPoint(x: centro.x - d.dx * ateCentro, y: centro.y - d.dy * ateCentro)
                }
                if natural > L + 2 { corte = CGFloat(med.centroY - med.diametro / 2) * lado - L }
            }
            var caixa = CGRect(x: centro.x - r, y: centro.y - r, width: 2 * r, height: 2 * r)
            if nome == "calcificado" { caixa = caixa.union(CGRect(x: centro.x - r, y: centro.y - r * 1.3, width: 2 * r, height: centroDesenho.y + lado * 0.48 - (centro.y - r * 1.3))) }
            if let p = pontaPediculo { caixa = caixa.union(CGRect(origin: p, size: .zero)) }
            out.append(Posicionado(n: i + 1, item: m, desenho: nome, centro: centro, r: r, centroDesenho: centroDesenho,
                                   lado: lado, angulo: ang, corteTopo: corte, caixa: caixa))
        }
        return out
    }

    // MARK: - Folha

    private static func desenharFolha(_ ctx: CGContext, _ itens: [MyomaSheetItem], _ geo: MyomaArtGeometry) {
        let PW = pageSize.width, MG = margem, CW = PW - 2 * MG
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: pageSize))
        texto("Mapa de miomas uterinos — classificação FIGO", CGPoint(x: MG, y: MG), 58, .semibold)

        let topo1 = MG + 110
        let r1 = vista(ctx, .coronal, itens, geo, slot: CGRect(x: MG, y: topo1, width: CW, height: 1450))
        lados(r1)
        texto("Vista frontal (coronal)", CGPoint(x: PW / 2, y: topo1 + 1460), 40, .medium, centro: true, cor: .darkGray)

        let topo2 = topo1 + 1570, gap: CGFloat = 70, w2 = (CW - gap) / 2
        _ = vista(ctx, .longitudinal, itens, geo, slot: CGRect(x: MG, y: topo2, width: w2, height: 900))
        texto("Longitudinal (sagital)", CGPoint(x: MG + w2 / 2, y: topo2 + 910), 40, .medium, centro: true, cor: .darkGray)
        let r3 = vista(ctx, .transversal, itens, geo, slot: CGRect(x: MG + w2 + gap, y: topo2, width: w2, height: 900))
        lados(r3)
        texto("Transversal", CGPoint(x: MG + w2 + gap + w2 / 2, y: topo2 + 910), 40, .medium, centro: true, cor: .darkGray)

        legenda(ctx, itens, topo: topo2 + 1000, x0: MG, largura: CW, limite: pageSize.height - MG)
    }

    /// Desenha uma vista enquadrada no `slot`; devolve o retângulo ocupado na folha.
    private static func vista(_ ctx: CGContext, _ v: Vista, _ itens: [MyomaSheetItem], _ geo: MyomaArtGeometry, slot: CGRect) -> CGRect {
        guard let g = geo.vistas[v.rawValue], let base = UIImage(named: v.imagem) else { return .zero }
        let pos = posicionar(v, itens, geo)
        let conteudo = CGRect(x: g.conteudo[0], y: g.conteudo[1], width: g.conteudo[2], height: g.conteudo[3])
        var caixa = pos.reduce(conteudo) { $0.union($1.caixa) }
        func escala(_ c: CGRect) -> CGFloat {
            let f = c.insetBy(dx: -24, dy: -24)
            return min(slot.width / f.width, slot.height / f.height)
        }
        // rótulos: tamanho fixo na folha → no espaço da arte depende da escala; duas passadas
        var k = escala(caixa)
        var rotulos = posicionarRotulos(pos, k)
        caixa = rotulos.reduce(caixa) { $0.union($1.caixa) }
        k = escala(caixa)
        rotulos = posicionarRotulos(pos, k)
        caixa = rotulos.reduce(pos.reduce(conteudo) { $0.union($1.caixa) }) { $0.union($1.caixa) }
        k = escala(caixa)
        let f = caixa.insetBy(dx: -24, dy: -24)
        let origem = CGPoint(x: slot.midX - f.width * k / 2 - f.minX * k, y: slot.midY - f.height * k / 2 - f.minY * k)
        let usado = CGRect(x: origem.x + f.minX * k, y: origem.y + f.minY * k, width: f.width * k, height: f.height * k)

        ctx.saveGState()
        ctx.clip(to: usado)
        ctx.translateBy(x: origem.x, y: origem.y)
        ctx.scaleBy(x: k, y: k)
        ctx.interpolationQuality = .high
        base.draw(in: CGRect(x: 0, y: 0, width: g.largura, height: g.altura))
        for p in pos {
            guard let img = UIImage(named: "MyomaSprite" + p.desenho.prefix(1).uppercased() + p.desenho.dropFirst()) else { continue }
            ctx.saveGState()
            ctx.translateBy(x: p.centroDesenho.x, y: p.centroDesenho.y)
            ctx.rotate(by: p.angulo)
            if let topo = p.corteTopo { ctx.clip(to: CGRect(x: -p.lado / 2, y: topo, width: p.lado, height: p.lado / 2 - topo)) }
            img.draw(in: CGRect(x: -p.lado / 2, y: -p.lado / 2, width: p.lado, height: p.lado))
            ctx.restoreGState()
        }
        ctx.restoreGState()
        // rótulos em tamanho fixo na folha
        for r in rotulos {
            let c = CGPoint(x: origem.x + r.caixa.midX * k, y: origem.y + r.caixa.midY * k)
            texto("M\(r.n)", c, fonteRotulo, .bold, centro: true, vertical: true, fundo: UIColor.white.withAlphaComponent(0.85))
        }
        return usado
    }

    private struct Rotulo { let n: Int; let caixa: CGRect }

    /// Rótulos acima, abaixo, à direita ou à esquerda — fica na 1ª posição que não cobre outro rótulo nem outro mioma.
    private static func posicionarRotulos(_ pos: [Posicionado], _ k: CGFloat) -> [Rotulo] {
        let discos = pos.map { $0.caixa.insetBy(dx: $0.r * 0.15, dy: $0.r * 0.15) }
        var ocupados: [CGRect] = []
        var out: [Rotulo] = []
        for (i, p) in pos.enumerated() {
            let s = NSAttributedString(string: "M\(p.n)", attributes: [.font: UIFont.systemFont(ofSize: fonteRotulo, weight: .bold)])
            let w = (s.size().width + 8) / k, h = s.size().height / k
            let c = p.centro, r = p.desenho == "calcificado" ? p.r * 1.7 : p.r
            let candidatos = [CGPoint(x: c.x, y: c.y - r - h * 0.6), CGPoint(x: c.x, y: c.y + r + h * 0.6),
                              CGPoint(x: c.x + p.r + w / 2 + 6, y: c.y), CGPoint(x: c.x - p.r - w / 2 - 6, y: c.y),
                              CGPoint(x: c.x, y: c.y - r - h * 1.7), CGPoint(x: c.x, y: c.y + r + h * 1.7)]
            func caixa(_ q: CGPoint) -> CGRect { CGRect(x: q.x - w / 2, y: q.y - h / 2, width: w, height: h) }
            let livre = candidatos.first { q in
                let b = caixa(q)
                return !ocupados.contains { $0.intersects(b) } && !discos.enumerated().contains { $0.offset != i && $0.element.intersects(b) }
            } ?? candidatos[0]
            ocupados.append(caixa(livre))
            out.append(Rotulo(n: p.n, caixa: caixa(livre)))
        }
        return out
    }

    // MARK: - Legenda

    static let tipos: [Int: String] = [
        0: "pediculado intracavitário", 1: "submucoso, < 50% intramural", 2: "submucoso, ≥ 50% intramural",
        3: "intramural em contato com o endométrio", 4: "intramural", 5: "subseroso, ≥ 50% intramural",
        6: "subseroso, < 50% intramural", 7: "subseroso pediculado", 8: "cervical / outros",
    ]

    static func local(_ l: MyomaLocation) -> String {
        switch l {
        case .fundo: return "fúndico"
        case .anterior: return "parede anterior"
        case .posterior: return "parede posterior"
        case .lateralDireita: return "parede lateral direita"
        case .lateralEsquerda: return "parede lateral esquerda"
        case .cervical: return "colo"
        case .notInformed: return "localização não informada"
        }
    }

    static func eixos(_ dims: [Double]) -> String {
        dims.map { String(format: "%.1f", $0 / 10).replacingOccurrences(of: ".", with: ",") }.joined(separator: " × ")
    }

    /// Linha da legenda: ("M1", "FIGO 5 · 2,6 × 2,4 × 2,2 cm", "subseroso, ≥ 50% intramural — parede lateral direita").
    static func linhaLegenda(_ n: Int, _ m: MyomaSheetItem) -> (String, String, String) {
        let figo = m.figo.map { "FIGO \($0)" } ?? "FIGO —"
        let medida = m.dimsMm.isEmpty ? "" : " · \(eixos(m.dimsMm)) cm"
        let tipo = m.figo.flatMap { tipos[$0] } ?? "classificação FIGO pendente"
        return ("M\(n)", figo + medida, "\(tipo)\(m.calcified ? ", calcificado" : "") — \(local(m.location))")
    }

    private static func legenda(_ ctx: CGContext, _ itens: [MyomaSheetItem], topo: CGFloat, x0: CGFloat, largura: CGFloat, limite: CGFloat) {
        guard !itens.isEmpty else { return }
        UIColor.lightGray.setFill()
        ctx.fill(CGRect(x: x0, y: topo, width: largura, height: 3))
        let muitos = itens.count > 5
        let fs: CGFloat = muitos ? 32 : 40
        var y = topo + 30
        for (i, m) in itens.enumerated() {
            let (id, figo, desc) = linhaLegenda(i + 1, m)
            texto(id, CGPoint(x: x0, y: y), fs, .bold)
            texto(figo, CGPoint(x: x0 + fs * 2.2, y: y), fs, .semibold)
            texto(desc, CGPoint(x: x0 + fs * 16.5, y: y), fs, .regular)
            y += muitos ? 40 : 62
            if y > limite - 30 { break }
        }
    }

    // MARK: - Texto

    private static func lados(_ r: CGRect) {
        guard r != .zero else { return }
        texto("D", CGPoint(x: r.minX + 10, y: r.minY + 10), 40, .bold, cor: .darkGray)
        let e = NSAttributedString(string: "E", attributes: [.font: UIFont.systemFont(ofSize: 40, weight: .bold)])
        texto("E", CGPoint(x: r.maxX - 10 - e.size().width, y: r.minY + 10), 40, .bold, cor: .darkGray)
    }

    /// Texto com o canto superior esquerdo em `p` (ou centrado em x / em x e y).
    private static func texto(_ s: String, _ p: CGPoint, _ size: CGFloat, _ peso: UIFont.Weight,
                              centro: Bool = false, vertical: Bool = false, cor: UIColor = .black, fundo: UIColor? = nil) {
        var attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: peso), .foregroundColor: cor]
        if let fundo { attrs[.backgroundColor] = fundo }
        let t = NSAttributedString(string: s, attributes: attrs)
        let sz = t.size()
        t.draw(at: CGPoint(x: centro ? p.x - sz.width / 2 : p.x, y: vertical ? p.y - sz.height / 2 : p.y))
    }
}
