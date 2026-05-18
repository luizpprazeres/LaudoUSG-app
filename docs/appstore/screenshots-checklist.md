# LaudoUSG — Checklist de Screenshots

App Store Connect exige screenshots em pelo menos um tamanho de iPhone. Apple ressize automaticamente pros demais formatos a partir do maior.

## Tamanhos exigidos (iOS 18+)

| Display size | Device sugerido pra capturar | Status |
|---|---|---|
| **iPhone 6.9"** | iPhone 16 Pro Max / iPhone 17 Pro Max | OBRIGATÓRIO |
| iPhone 6.7" | iPhone 14/15 Pro Max | Gerado por resize automático |
| iPhone 6.5" | iPhone XS Max / 11 Pro Max | Gerado por resize automático |

**Recomendação:** capturar 5 cenas no **iPhone 16 Pro Max** (6.9") no Simulator. Resoluções: **1320 × 2868 px**.

## Como capturar

1. Xcode: **File → Open** → seleciona LaudoUSG.xcodeproj
2. Scheme: LaudoUSG
3. Destination: **iPhone 16 Pro Max** (ou iPhone 17 Pro Max se disponível)
4. Cmd+R → app inicia no Simulator
5. Simulator → **Device → Erase All Content and Settings** (recomendado pra começar limpo)
6. Faz signup novo OU usa o demo account `apple-review@laudousg.com`
7. Pra cada cena abaixo:
   - Navegue até a tela
   - Simulator: **Cmd+S** (Save Screenshot) — sai PNG em `~/Desktop/`
   - Renomeia conforme tabela

## 5 cenas a capturar

### 1. `01-login.png` — Tela de login
**Como chegar:** logout (se logado) → tela inicial
**Composição:**
- Logo "LaudoUSG" centralizado
- Campos Email + Senha (vazios ou com placeholder)
- Botão verde "Entrar"
- Link "Esqueci minha senha"
- Link "Cadastre-se"
- Footer com links pequenos "Termos / Privacidade" + "Seus laudos são privados. Revise antes de assinar."

**Sugestão de texto sobreposto (no App Store):**
> "Pronto pra ditar"

### 2. `02-generate-achados.png` — Aba ACHADOS com ditado de exemplo
**Como chegar:** login → seleciona "Abdome Total" → cole/dite um exemplo (sem dados de paciente)
**Texto sugerido pra colar manualmente:**
> "Fígado de dimensões e ecotextura normais. Vesícula biliar com paredes finas, sem cálculos. Vias biliares sem dilatação. Pâncreas parcialmente visualizado, sem alterações detectáveis. Rins de dimensões e ecogenicidade preservadas."

**Composição:**
- Header com BrandLogo + categoria selecionada
- Tab "ACHADOS" ativa (mostrando texto digitado)
- Bottom toolbar: [+] | [Gerar laudo] | [🎤]

**Sugestão de texto sobreposto:**
> "Dite os achados em segundos"

### 3. `03-generate-laudo.png` — Aba LAUDO com minuta gerada
**Como chegar:** após capturar a cena 2, toca "Gerar laudo" → aguarda IA completar → muda pra tab LAUDO
**Composição:**
- Tab "LAUDO" ativa
- Texto estruturado da minuta gerada
- Sem footer warning ainda (esse aparece em ReportDetail)

**Sugestão de texto sobreposto:**
> "IA estrutura. Você revisa."

### 4. `04-report-detail.png` — Laudo no histórico com disclaimer
**Como chegar:** menu → Histórico → toca no laudo recém-gerado
**Composição:**
- Texto completo do laudo (rolar até o final pra mostrar o footer)
- **Footer disclaimer médico visível** com fundo amarelo de aviso (`SemanticColor.warningBg`)
- Ícone de exclamação amarelo
- Texto "Laudo elaborado com apoio de inteligência artificial..."

> ⚠️ **Crítico:** essa screenshot mostra o compromisso de transparência do app. Apple Review valoriza apps médicos que deixam claro que IA não substitui médico.

**Sugestão de texto sobreposto:**
> "Você é o responsável final"

### 5. `05-menu-sobre.png` — Menu lateral com "Sobre o LaudoUSG"
**Como chegar:** Generate → toca menu hamburger (3 linhas no canto superior esquerdo)
**Composição:**
- Header com badge do plano (ex: "Gratuito") + nome do médico + email
- Lista de entries:
  - Histórico
  - Analytics
  - Biblioteca
  - Preferências
  - **Sobre o LaudoUSG** (recente, ícone info)
  - Sair (vermelho)

**Sugestão de texto sobreposto:**
> "Transparente sobre IA e privacidade"

## Alternativa pra cena 5: Settings → Editar perfil

Se quiser variar:
- Menu → Preferências → toca "Editar perfil"
- Mostra Nome / CRM / UF preenchidos
- Botão "Salvar" verde

Vale como prova social de que o app valida elegibilidade profissional.

## Pós-captura

1. Verifica que cada screenshot tem **1320 × 2868 px** (Cmd+I na Finder pra confirmar)
2. Se quiser melhorar visualmente: pode adicionar textos sobreposto/molduras em ferramentas como:
   - **Screenshots.pro** (online, grátis até X imgs)
   - **Picsew** (Mac, $5)
   - **Figma** (template "App Store Screenshot" — grátis)
3. Upload no App Store Connect → My Apps → LaudoUSG → 1.0 Prepare for Submission → iPhone 6.9 Display → arrasta as 5 imagens em ordem

## Notas

- **Não use** screenshots com dados reais de pacientes (mesmo que fake — pra ficar 100% defensável que LaudoUSG não tem dados de paciente)
- **Não use** logos/marcas de hospitais reais
- **Demo content** preferido: descrições genéricas de achados sem identificação

---

## Roteiro de captura em 10 min

```
1. Cmd+R no Xcode (iPhone 16 Pro Max simulator)
2. Cmd+Shift+H → home → fecha apps
3. Logout (se logado)
4. Cena 1: tela de login → Cmd+S
5. Login com demo
6. Seleciona "Abdome Total"
7. Cola texto de exemplo na aba ACHADOS
8. Cena 2: Cmd+S
9. Toca "Gerar laudo" → aguarda
10. Cena 3 (tab LAUDO): Cmd+S
11. Menu → Histórico → toca laudo gerado
12. Rola até ver footer disclaimer
13. Cena 4: Cmd+S
14. Volta → toca menu lateral
15. Cena 5: Cmd+S
16. ~/Desktop/ tem 5 PNGs renomeáveis
```

Tempo total: ~10-15 min.
