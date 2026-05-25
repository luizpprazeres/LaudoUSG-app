# Roadmap — Esquema visual de miomas uterinos (FIGO PALM-COEIN 0-8)

> Status: **PLANEJAMENTO** — não implementar antes de validar mockup com o user.
> Discutido em 2026-05-24 a partir das 2 imagens enviadas (US 2D + reconstrução 3D + diagrama FIGO 0-8).
> Diferencial: nenhuma plataforma de laudo no mercado oferece isso em 2D simples.

---

## Por que vale a pena

1. **Padrão FIGO existe e é universal** — 9 buckets discretos (0-8) cobrem toda a anatomia possível do mioma uterino. Aprendido em residência, usado em todo laudo.
2. **O backend JÁ extrai e usa FIGO no texto** — temos ground truth pra parsear:
   - Regex em `golden-validation.ts`: `FIGO\s*[:\-]?\s*([0-6][ABC]?|IV[ABC]?|...)`
   - Documentação em `_extraction/from-laudousg-original/04-rules-by-category/PELVE_FEMININA.md`
   - Deepgram boost com termos: `mioma, leiomioma, intramural, submucoso, subseroso, pediculado, FIGO`
3. **Padrão de descrição já estável no codebase** — exemplos few-shot mostram:
   ```
   "Miométrio apresentando imagem hipoecoica e heterogênea, com margens regulares,
   medindo 2,3 x 1,8 x 2,0 cm, situada na parede anterior, intramural.
   CONCLUSÃO: ... nódulo miomatoso intramural (categoria FIGO 4)."
   ```
4. **A web não tem esquema visual** — diferencial real e marketing-friendly.

---

## Por que é desafiador (riscos reconhecidos pelo user)

| Risco | Mitigação |
|---|---|
| Sem referência visual estabelecida | Mockup HTML antes de codar; iterar com user |
| Anatomia 3D em 2 visões 2D perde profundidade | 2 visões complementares (sagital + transversal) cobrem 95% dos casos |
| Útero varia muito (AVF, RVF, miomatoso, gestante) | UM SVG funciona pra todos — variações são esperadas e aceitáveis |
| Múltiplos miomas (5-20+) em úteros miomatosos | Honeycomb spread + lista textual lateral; talvez limite visual de N markers |
| Tamanhos extremos (0,5 cm vs 15 cm) | Escala logarítmica do raio do marker; tamanho exato no label |
| FIGO 8 é wildcard ("outros: cervical, parasitário") | Área extra abaixo do colo OU marker flutuante "Outros" |

---

## Classificação FIGO PALM-COEIN (referência médica)

| FIGO | Tipo | Descrição |
|---|---|---|
| 0 | Submucoso pediculado | Intracavitário, com haste |
| 1 | Submucoso | < 50% intramural, faz contato com endométrio |
| 2 | Submucoso | ≥ 50% intramural, faz contato com endométrio |
| 2-5 | Transmural | Atinge tanto endométrio quanto serosa (raro) |
| 3 | Intramural | 100% intramural, contato com endométrio |
| 4 | Intramural | 100% intramural, sem contato com endométrio |
| 5 | Subseroso | ≥ 50% intramural, contato com serosa |
| 6 | Subseroso | < 50% intramural, contato com serosa |
| 7 | Subseroso pediculado | Externo, com haste |
| 8 | Outros | Cervical, ligamento largo, parasitário, retroperitoneal |

PALM-COEIN é o sistema amplo de classificação de sangramento uterino anormal. O LaudoUSG usa só a parte **L (leiomioma)** com a sub-classificação FIGO 0-8 — confirmar com user se queremos contemplar outros (Pólipo, Adenomiose, Malignidade, Coagulopatia, Endometrial, Iatrogênica, Not yet classified) ou só miomas.

---

## Arquitetura proposta (2 visões 2D)

### Visão A — Longitudinal (sagital)

Útero em corte sagital (vista lateral), formato pera com:
- **Fundo uterino** (topo arredondado)
- **Corpo uterino** (porção mais larga)
- **Istmo** (estreitamento)
- **Colo uterino** (base)
- **Cavidade endometrial** (linha central no meio do corpo, em forma de "T" invertido)
- **Parede anterior e posterior** (espessura visível, ~1/3 do diâmetro)
- **Serosa** (contorno externo)

Mapping FIGO 0-7 nessa visão (com posição angular ao redor da cavidade endometrial):
- **0**: pequeno círculo DENTRO da cavidade, com haste fina
- **1, 2**: círculos adjacentes ao endométrio (1 menos invadindo a parede, 2 mais)
- **3**: dentro da parede mas tocando endométrio
- **4**: centralizado dentro da parede (sem tocar endométrio nem serosa)
- **5, 6**: perto da serosa (5 mais imerso, 6 mais para fora)
- **7**: fora do contorno, com haste fina

Posicionamento típico (parede anterior ou posterior é escolhido pelo médico no editor).

### Visão B — Transversal (axial)

Útero em corte transversal (visto de cima/baixo), formato disco com:
- **Cavidade endometrial central** (oval)
- **Parede anterior, posterior, lateral direita, lateral esquerda**
- **Cornos uterinos** (raros, mas marcáveis)

Essa visão **complementa a longitudinal** pra desambiguar parede direita ↔ esquerda. Sem ela só conseguimos dizer "anterior/posterior".

### Switcher entre visões

Tab no topo da sheet: "Longitudinal" / "Transversal". Marcadores são vinculados a uma visão (ou ambas — médico marca onde considera relevante).

---

## Modelo de dados (rascunho)

```swift
struct MyomaFinding {
    let id: String
    var localizacao: Localizacao   // anterior, posterior, lat D, lat E, fundo, cervical
    var figoClass: Int             // 0-8
    var perimuralPct: Int?         // 0-100 — opcional pros 1/2/5/6
    var sizeMaxMm: Double?         // maior eixo
    var sizesMm: (h: Double, w: Double, d: Double)?  // 3 dimensões opcionais
    var ecotextura: String?        // hipoecoica/heterogênea/calcificada/degenerada
    var view: ViewType             // sagital, transversal, both
    var approximate: Bool
    var source: Source             // parsed | manual
}

enum Localizacao: String {
    case anterior, posterior
    case lateralDireita, lateralEsquerda
    case fundo
    case cervical
    case anexialDireita, anexialEsquerda  // p/ FIGO 7 e 8
}
```

---

## Plano incremental (com mockup prévio)

| Step | Escopo | Risco | Saída |
|---|---|---|---|
| **0** | **Mockup HTML standalone** (2 SVGs sagital + transversal com FIGO 0-8 marcados). Aberto no navegador pro user validar visual antes de codar. | Alto-mitigado | `docs/design/mockups/miomas-esquema.html` |
| **1** | Modelo `MyomaFinding` + 2 ViewShape (sagital, transversal) estáticas em SwiftUI. Toggle entre visões. | Médio | View renderiza com hardcoded findings |
| **2** | Editor manual: FIGO (segmented 0-8) + localização (Picker) + tamanho (TextField) + ecotextura opcional | Baixo | CRUD manual funcional |
| **3** | Drag entre buckets na visão atual; markers respeitam bucket FIGO | Médio | Igual tireoide drag |
| **4** | Parser regex PT: extrai FIGO X + localização + tamanho + ecotextura do laudo gerado | Médio-alto | Auto-import na abertura |
| **5** | Exporter PDF landscape com **2 páginas** (uma por visão) + PNG + gate pós-laudo | Baixo | Paridade com mama/tireoide |

---

## 3 decisões a alinhar quando começar

1. **PALM-COEIN completo ou só L (miomas)?**
   - Só L (recomendado MVP): foco no que o backend já estrutura
   - PALM-COEIN completo: pólipos, adenomiose, etc — esquema muito mais complexo
2. **Visão default ao abrir**: longitudinal ou transversal?
3. **Tamanho do marker**: proporcional ao maior eixo OU ao volume (h × w × d × 0,523)?

---

## Quando começar

**Não antes de**:
- Esquema mamário estabilizado em TestFlight (S17.6 done)
- Esquema tireoidiano completo (Steps 1-5 done)
- Pelo menos 1 ciclo de feedback dos beta testers nos esquemas anteriores

Esse roadmap fica em standby como **diferencial estratégico futuro**.
