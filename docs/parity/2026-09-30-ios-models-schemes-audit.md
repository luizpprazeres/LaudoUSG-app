# Paridade iOS: categorias, modelos e esquemas visuais — 2026-09-30

Escopo: checkout iOS `LaudoUSG`; backend/Web de `laudousgmobile-def` consultados para comparação. O catálogo clínico não foi ampliado sem aprovação. A conferência de produção ficou restrita às duas flags do mapa venoso, sem ler laudos ou dados de paciente.

## Seleção de categoria para exame novo

Conjunto esperado, codificado em `ReportCategory.selectable` e protegido por `CategorySelectionTests` (29 códigos):

```text
ABDOMEN_TOTAL
ABDOMEN_SUPERIOR
VIAS_URINARIAS
TIREOIDE
PARATIREOIDE
CERVICAL
GLANDULAS_SALIVARES
MAMARIA
PELVE_FEMININA
OBSTETRICA
DOPPLER_OBSTETRICO
MORFOLOGICO
CERVICOMETRIA
MUSCULOESQUELETICO_V2
ESCROTAL
REGIAO_INGUINAL
PAREDE_ABDOMINAL
PARTES_MOLES
PROSTATA_TRANSRETAL
PROSTATA_SUPRAPUBICA
TRANSFONTANELA
DOPPLER_CAROTIDAS
DOPPLER_VENOSO_MMII
DOPPLER_VENOSO_MMII_MEDIDAS
DOPPLER_ARTERIAL_MMII
DOPPLER_FISTULA_AV
DOPPLER_RENAL
OCULAR
LIVRE
```

`CERVICOMETRIA` já consta no seed do backend (`packages/db/src/seeds/data.ts`), na extração (`apps/api/src/server/renderer/extraction.ts`), no registro de modelo normal (`catalog/modeloNormalRegistry.ts`) e no teste focal `modelos-pendentes-cervicometria.manual.ts`. O iOS passou a enviar esse código no `category_hint`, sem criar modelo clínico local. `ABDOMEN_TOTAL_DOPPLER` e `MUSCULOESQUELETICO_RARAS` continuam no enum/`Codable` para histórico, mas são experimentais e ficam fora da seleção de novos exames. As demais categorias anteriormente selecionáveis permanecem.

O seed do backend é mais amplo que o seletor iOS: `DOPPLER_VENOSO_MMSS`, `DOPPLER_ARTERIAL_MMSS`, `TORAX`, `QUADRIL_INFANTIL` e `TESTE` não foram ativados aqui. Presença no seed não equivale a aprovação clínica para exposição no app. A Biblioteca iOS usa o catálogo e as personalizações servidos por `/api/me/report-customizations` (`ModelCustomizationService.swift`), em vez de manter uma cópia local do texto dos modelos.

## Esquemas visuais

**Tireoide.** Antes, o iOS mostrava uma base vetorial frontal única (`ThyroidSchemaView.swift`), enquanto a Web usa `frontal-v2.png` e `transverse-v2.png` (`apps/web/src/components/visualSchemas/ThyroidSchema.tsx`). Os dois PNGs da Web foram incorporados ao asset catalog iOS com bytes idênticos. `ThyroidDualViewSchema` agora mostra ambas as vistas na tela e nas exportações PNG/PDF; o mesmo achado aparece nas duas. O arraste frontal classifica lobo/terço ou istmo; o transverso classifica lobo ou istmo e conserva o terço já conhecido, sem inferir profundidade. Esta é paridade de apresentação e posicionamento, sem alterar achados clínicos.

**Venoso MMII.** O PNG iOS `Venous4View.imageset/venous-4view.png` é byte a byte igual ao asset Web `venous-4view-v1.png` (SHA-256 `85b462a51d996d0fc7aab9e6d055a16b2bed1dc0501c7f984743a5ccde3d9e6d`). O iOS já decodifica o evento SSE `scheme` e renderiza `venous-4view-1` e `venoso-anterior-1`; não faltava atualização do desenho. No backend, o evento só sai quando `VENOUS_SCHEME_MAP=true` e a categoria efetiva é `DOPPLER_VENOSO_MMII`; quatro vistas dependem também de `VENOUS_SCHEME_4VIEW=true` (`apps/api/src/app/api/generate/route.ts`). As duas flags foram conferidas como `true` na produção em 30/09/2026. O iOS não tem como garantir um mapa para `DOPPLER_VENOSO_MMII_MEDIDAS`; nessa categoria, o atalho visual agora só aparece se houver payload recebido, preservando acesso a um eventual laudo antigo com mapa. A entrada de Doppler venoso MMII informa quando o mapa ainda não chegou.

## Validação e limites

Build iOS Simulator e 12 testes focais de seleção/decodificação de categorias, contrato `category_hint`, geometria das duas vistas tireoidianas e presença dos assets passaram. Não houve teste em dispositivo físico nem validação clínica de conteúdo novo; nenhum dos cinco rascunhos pendentes foi ativado.
