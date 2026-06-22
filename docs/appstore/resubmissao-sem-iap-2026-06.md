# Resubmissão App Store — LaudoUSG SEM compras in-app (2026-06)

> App rejeitado por **Guideline 2.1(b)** (referências a assinaturas PRO sem submeter produtos IAP).
> Correção: **remover todo IAP e qualquer referência a compra/assinatura/preço**. As assinaturas
> são contratadas **fora do app** (web). O app só reflete o status do plano (`profiles.plan`).
> App: **LaudoUSG** · Bundle: `com.laudousg.LaudoUSG` · Versão: **1.0**.
> **Último build no App Store Connect: 141 → próxima build: 142** (não use número menor).

---

## 0. O que mudou no código (commitado/pushado — repo LaudoUSG-app, branch main)
- `a8fa0c8` — remove IAP/StoreKit; `e4366d6` — fix picker; `25bab14` — streaming; `3ad4555` — feedback 👍/👎.
- `04c5334` — remove "Gerenciar assinatura"→Apple e "plano PRO" do tour.
- `0dd7ff0` — **máximo Apple-safe** (review dos Dex): remove página de trial do tour, PaywallSheet vira
  "Acesso restrito" (sem site/preço/link), Settings só mostra status do plano, terms sem "Planos e
  Pagamento", e reconhece o plano **clinic** (Profissional) — corrige usuário pago aparecendo como Gratuito.
- Validado: `xcodebuild -scheme LaudoUSG` → **BUILD SUCCEEDED**. Varredura: zero StoreKit/IAP/links de compra.

## 1. Antes de arquivar (Xcode)
- [ ] **Build = 142** (maior que 141, o último aceito). Setar em Xcode → target → General/Build,
      ou no esquema que você usa para subir (o `project.pbxproj` do repo mostra 77, mas seus uploads
      usaram 129–141, então o número vem do seu Xcode, não do arquivo commitado — só garanta 142).
- [ ] Archive → Distribute App → App Store Connect → Upload.

## 2. App Store Connect — passos

### 2.1 In-App Purchases (resolve a 2.1b)
- [ ] Em **Recursos → Compras no app / Assinaturas**: NÃO anexar nenhum produto IAP a esta versão.
      Os produtos `laudousg.pro.monthly/yearly`, se existirem, ficam **fora** desta versão (Removed from Sale).
      O novo binário não referencia IAP.

### 2.2 Nova versão → "Novidades desta versão" (What's New) — texto pronto
```
- Acompanhamento do progresso em tempo real durante a geração do laudo.
- Agora você pode avaliar a qualidade de cada laudo gerado.
- Melhorias de estabilidade e ajustes de interface.
```

### 2.3 Preços e disponibilidade
- [ ] App **gratuito** (Free). Sem assinaturas vendidas pela App Store.

### 2.4 Build
- [ ] Selecionar a **build 142** (depois que processar no App Store Connect).

### 2.5 Informações para a revisão (App Review Information)
- [ ] **Demo account** (já provisionado e validado no banco — confirmado free, termos+onboarding OK):
  ```
  Email:    apple-review@laudousg.com
  Password: apple12345
  ```
- [ ] **Notes:** usar o texto da seção 3.

## 3. App Review Notes — TEXTO PRONTO (cole no campo "Notes")
```
LaudoUSG é um app B2C-profissional para médicos ultrassonografistas brasileiros: o médico dita os
achados de um exame de ultrassonografia e recebe uma minuta de laudo estruturada por IA. Ele revisa,
edita e assina o laudo — é sempre o responsável clínico.

SOBRE ASSINATURAS (IMPORTANTE)
Esta versão NÃO possui compras in-app e NÃO direciona o usuário a nenhum mecanismo de compra. O app
apenas reflete o status do plano da conta. A conta de demonstração abaixo tem acesso completo para
avaliar todas as funcionalidades do app. O app não exibe preços nem qualquer mecanismo de compra.

ACESSO PARA REVIEW
Demo account pré-configurado (sem necessidade de confirmar email nem aceitar termos — já pré-aceitos):
Email:    apple-review@laudousg.com
Password: apple12345

ROTEIRO DE TESTE (5 minutos)
1. Abrir o app → Login com as credenciais acima.
2. "Selecionar categoria" → "Abdome Total".
3. Microfone (🎤) → dite ~10-15s (ex.: "fígado com dimensões e ecotextura normais, vesícula biliar de
   paredes finas sem cálculos, vias biliares sem dilatação") → "Parar e usar".
4. Aguarde a transcrição (~5s) → texto na aba ACHADOS.
5. "Gerar laudo" → laudo gerado por IA em streaming na aba LAUDO (~10-20s).
6. O laudo é editável; há um footer obrigatório com aviso médico ao final.
7. (Opcional) Avalie o laudo com 👍/👎.
8. Configurações → "Sobre o LaudoUSG" (versão + documentos legais) e "Excluir minha conta".

OBSERVAÇÕES TÉCNICAS
— App requer autenticação (sem modo guest). Demo tem CRM dummy aceito.
— Não armazena dados identificáveis de pacientes (despersonalizado por design — Termos 5.2).
— IA: OpenAI Whisper (transcrição) + gpt-4.1-mini (texto), via backend próprio. Áudio descartado após transcrição.
— Permissão: Microfone (ditado). Câmera está no Info.plist mas não é usada na versão atual.
— Deep link laudousg:// usado para confirmação de email e recuperação de senha.

CONFORMIDADE
— LGPD (13.709/2018), Marco Civil, Guidelines §5.1 (Privacy), Resolução CFM 2.314/2022.
— Disclaimer médico no signup, no footer de todo laudo e em Configurações.

Dúvidas: contato@laudousg.com (resposta em até 24h). Obrigado.
```

## 4. Checklist final
- [ ] Build 142 arquivada e enviada (sem IAP).
- [ ] Nenhum produto IAP anexado à versão.
- [ ] What's New + Review Notes preenchidos.
- [ ] Demo account confirmado (já está).
- [ ] Enviar para revisão.

> Revisão de compliance feita por Dex1 (adversarial) + Dex2 (funcional): trial do tour, paywall,
> links externos e bug do plano clinic — todos corrigidos e validados (build OK).
