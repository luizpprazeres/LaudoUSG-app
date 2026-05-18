# LaudoUSG — Conteúdo App Store Connect (pt-BR)

Use diretamente em **App Store Connect → My Apps → LaudoUSG → Portuguese (Brazil)**.

---

## Subtitle (max 30 chars)

```
Laudos de USG com IA
```

20 chars — sobra espaço. Alternativas:
- `IA pra laudos de ultrassom` (26 chars)
- `Laudos de ultrassom com IA` (26 chars)

---

## Promotional Text (max 170 chars — atualizável sem nova submissão)

```
Laudos de ultrassonografia mais rápidos. Você dita os achados, a IA estrutura uma minuta. Você revisa, edita e assina.
```

117 chars.

---

## Description (max 4000 chars)

```
O LaudoUSG é um assistente de elaboração de laudos de ultrassonografia para médicos brasileiros. Você dita os achados do exame; uma minuta estruturada é gerada por inteligência artificial. Você revisa, edita e assina o laudo final.

POR QUE LAUDOUSG

— Tempo de laudo reduzido: ditado natural em português é transcrito e organizado em minuta seguindo o estilo que você escolher (Tradicional, Estruturado ou Livre).
— Sem digitação repetitiva: medidas, características técnicas e descrição de imagem são estruturadas automaticamente.
— Categorias clínicas específicas: Abdome Total, Tireoide, Mama, Obstetrícia, Pélvico, Doppler e outras — cada uma com vocabulário e regras próprias.

COMO FUNCIONA

1. Escolha a categoria do exame.
2. Dite os achados (ou digite).
3. Receba uma minuta estruturada em segundos.
4. Revise, corrija e assine — você é o responsável final pelo conteúdo clínico.

SALA DO AUXILIAR

Recurso exclusivo: gere um código de sessão para um auxiliar de consultório acompanhar e digitar pelo computador enquanto você ditar. Sem precisar instalar nada no PC do auxiliar — funciona pelo navegador em laudousg.com/sala.

PRIVACIDADE PRIMEIRO

O LaudoUSG não coleta, não armazena e não solicita dados identificáveis de pacientes. Nem imagens de ultrassonografia. Os achados são despersonalizados por design.

Você, médico, permanece controlador dos dados de seus pacientes — em conformidade com a LGPD (Lei 13.709/2018) e o Código de Ética Médica.

INTELIGÊNCIA ARTIFICIAL COM RESPONSABILIDADE

A IA gera minuta automatizada — não realiza diagnóstico, não toma decisão clínica e não substitui o exame ultrassonográfico nem seu julgamento profissional. O laudo final é sempre revisado e assinado por você.

Em conformidade com a Resolução CFM 2.314/2022 (Telemedicina) e demais normas vigentes do Conselho Federal de Medicina.

PARA QUEM

Profissionais médicos com registro ativo no Conselho Regional de Medicina (CRM), em qualquer estado brasileiro. Validação de credenciais no cadastro.

GRATUITO PARA COMEÇAR

— 20 laudos gratuitos por conta, vitalícios.
— Plano Essencial mensal disponível em breve via assinatura.

DISCLAIMER MÉDICO

LaudoUSG é ferramenta de apoio à redação de laudos. Não realiza diagnóstico. O conteúdo gerado é proposta editorial automatizada, sujeita à revisão crítica e validação clínica integral por médico habilitado. Você é o único e final responsável pela acurácia do laudo.

Não use em situações de urgência, emergência, paciente instável ou quando não puder revisar integralmente a saída antes de assinar.

Termos completos em laudousg.com/terms
Política de Privacidade em laudousg.com/privacy

Atendimento e dúvidas: contato@laudousg.com
```

Conta: 2.486 chars (cabe folgado).

---

## Keywords (max 100 chars)

```
laudo,ultrassonografia,ultrassom,USG,ecografia,doppler,obstetrícia,medicina,IA,ditado
```

84 chars. Ordem por relevância de busca:
1. `laudo` — busca direta
2. `ultrassonografia` — termo médico oficial
3. `ultrassom` — termo popular
4. `USG` — sigla profissional
5. `ecografia` — sinônimo
6. `doppler` — exame específico de alta busca
7. `obstetrícia` — segmento médico
8. `medicina` — categoria
9. `IA` — diferencial
10. `ditado` — funcionalidade

> ⚠️ **Não incluir** o nome "LaudoUSG" — Apple já indexa pelo nome do app, seria desperdício de chars.

---

## Support URL

```
https://laudousg.com/suporte
```

Se ainda não existir: criar página simples com email de contato + FAQ básico (5-10 perguntas comuns).

---

## Marketing URL (opcional mas recomendado)

```
https://laudousg.com
```

---

## Privacy Policy URL (OBRIGATÓRIO)

```
https://laudousg.com/privacy
```

→ Publique `site-privacy.html` desta pasta nessa URL.

---

## App Information

| Campo | Valor |
|---|---|
| **App Name** | LaudoUSG |
| **Subtitle** | Laudos de USG com IA |
| **Primary Category** | Medicine |
| **Secondary Category** | Productivity |
| **Content Rights** | "I have the rights to use this content" ✅ |

---

## Age Rating

Marcar as seguintes opções no questionário:

| Categoria | Resposta |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | **Frequent/Intense** ⚠️ (porque o app gera conteúdo médico) |
| Alcohol, Tobacco, or Drug Use | None |
| Simulated Gambling | None |
| Unrestricted Web Access | None |
| Gambling and Contests | None |

**Resultado esperado: 17+**

Esse rating é normal pra apps médicos profissionais. Não impacta downloads do público-alvo (médicos).

---

## Pricing (Fase 1 — Free)

- **Price Schedule:** Free
- **Availability:** Brazil only (initial)

Em sprint futuro (12+), quando IAP estiver implementado:
- Adicionar produto "essencial-mensal" no ASC → In-App Purchases
- Preço: R$ 99,90/mês
- Tier: ajustar pra preço base equivalente em USD (Apple converte)

---

## Notas pra futuro (Sprint 12+)

- [ ] Quando expandir pra outros países: traduzir Description, Subtitle, Promotional, Keywords pra Spanish (LatAm) e English
- [ ] Quando ativar IAP: configurar produtos + atualizar Terms Cláusula 9 + atualizar app pra exibir paywall
