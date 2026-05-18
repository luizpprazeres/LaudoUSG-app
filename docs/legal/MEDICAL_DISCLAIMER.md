# Disclaimer Médico — LaudoUSG

> **Versão:** 1.2 (draft Sprint 11 — aplicado P0 + 7 P1 prioritários da revisão jurídica interna)
> **Última atualização:** 2026-05-18
> **Status:** Rascunho profissional — REQUER revisão jurídica + revisão médica antes de produção
> **Conformidade:** Resolução CFM 2.314/2022 (Telemedicina), Código de Ética Médica (Capítulos III e IX), demais normas vigentes do Conselho Federal de Medicina sobre uso de inteligência artificial em medicina (a confirmar referência específica com advogado especializado em direito médico)

---

## Versões deste Disclaimer

Este documento contém **três versões** do disclaimer, usadas em locais distintos do app:

1. **Versão completa** — exibida em modal de aceite na primeira geração de laudo + em Configurações
2. **Versão resumida** — exibida como footer obrigatório em todo laudo gerado (ReportDetail)
3. **Versão curta** — exibida em telas onde espaço é limitado (Generate, Login)

---

## 1. Versão Completa (modal de aceite + Configurações)

### LaudoUSG é uma ferramenta de APOIO. Não realiza diagnóstico.

Ao usar o LaudoUSG, você, profissional médico cadastrado, declara compreender e concordar que:

#### 1.1 Natureza da ferramenta

- O LaudoUSG é um **assistente de elaboração de laudos** baseado em inteligência artificial generativa (Whisper para transcrição; modelos de linguagem para estruturação e redação);
- O conteúdo gerado pelo LaudoUSG é **minuta automatizada de laudo** ou **sugestão automatizada de redação clínica**, que requer **revisão crítica, edição quando necessária e validação clínica integral** por médico habilitado;
- O LaudoUSG **não toma decisão diagnóstica, terapêutica ou prognóstica**, não prescreve conduta, não substitui exame clínico nem avaliação direta do paciente. Qualquer hipótese, conclusão ou formulação diagnóstica eventualmente redigida pelo sistema é apenas **sugestão textual sujeita à validação do médico Usuário**.

#### 1.2 Suas responsabilidades

Como médico Usuário, você é o **único e final responsável** por:

- **Verificar a acurácia clínica** de todo conteúdo gerado pelo LaudoUSG;
- **Corrigir** erros, omissões, imprecisões terminológicas, interpretações inadequadas ou conclusões clinicamente incorretas;
- **Validar e assinar** o laudo final, assumindo responsabilidade profissional plena pelo conteúdo;
- **Comunicar adequadamente** os achados ao paciente ou ao médico solicitante;
- **Não submeter** ao LaudoUSG dados identificáveis de pacientes (ver [Termos de Uso, Cláusula 5.2](./TERMS_OF_USE.md));
- **Cumprir** as normas do Conselho Federal de Medicina, do seu Conselho Regional, e a legislação aplicável.

#### 1.3 Limitações da inteligência artificial

Você reconhece que:

- Sistemas de IA generativa podem produzir **resultados imprecisos, incompletos ou factualmente incorretos** ("alucinações");
- A IA pode **omitir achados clinicamente relevantes** presentes no ditado;
- A IA pode **inserir terminologia ou medidas** que não correspondem ao ditado original;
- A IA pode **propor conclusões diagnósticas** que **não são** diagnósticos médicos válidos sem validação humana;
- A acurácia da IA varia conforme qualidade do ditado, ruído ambiente e clareza do conteúdo de entrada.

#### 1.3-A Quando NÃO usar o LaudoUSG

Você **não deve** usar o LaudoUSG como única base para decisão clínica ou em situações nas quais não consiga revisar integralmente a saída antes de assinar. O LaudoUSG **não deve ser usado**:

- Em **urgência, emergência, paciente instável** ou situação tempo-dependente sem validação médica direta;
- Quando houver **dúvida clínica relevante** que exija reavaliação do exame, revisão de imagens, exame complementar ou discussão com outro profissional;
- Quando a **qualidade do áudio, ditado, texto de entrada ou contexto clínico** for insuficiente para revisão segura;
- Para **comunicar diagnóstico, prognóstico ou conduta ao paciente** sem mediação humana;
- Para **substituir registro em prontuário, consentimento informado, sigilo profissional** ou deveres éticos do médico;
- Quando o **paciente ou a instituição recusar o uso de IA** em contexto no qual tal recusa deva ser respeitada.

#### 1.4 O que o LaudoUSG NÃO faz

- **Não realiza** diagnóstico clínico;
- **Não substitui** o exame ultrassonográfico nem o juízo do médico examinador;
- **Não armazena** dados identificáveis de pacientes (por design — usuário não deve inseri-los);
- **Não armazena** imagens de ultrassonografia;
- **Não envia** o laudo ao paciente, ao SUS ou a qualquer sistema externo automaticamente;
- **Não pratica medicina**.

#### 1.5 Conformidade regulatória

O LaudoUSG é desenvolvido em conformidade com:

- **Resolução CFM 2.314/2022** — Define e disciplina a Telemedicina, dispondo sobre seu exercício;
- **Demais normas do Conselho Federal de Medicina** aplicáveis ao uso de inteligência artificial em medicina, conforme regulamentação vigente *(referência específica a confirmar com advogado especializado em direito médico)*;
- **Código de Ética Médica** — Resolução CFM 2.217/2018, em especial:
  - **Capítulo III** (Responsabilidade Profissional): vedação ao médico de "deixar de assumir responsabilidade sobre procedimento médico que indicou ou do qual participou" (Art. 1º);
  - **Capítulo IX** (Sigilo Profissional): obrigação de manter sigilo das informações de seus pacientes (Art. 73);
- **Lei Geral de Proteção de Dados** (Lei 13.709/2018);
- **Marco Civil da Internet** (Lei 12.965/2014).

#### 1.6 Aceitação

Ao tocar em **"Entendi e aceito"** abaixo, você declara ter lido, compreendido e aceito integralmente este Disclaimer, bem como os [Termos de Uso](./TERMS_OF_USE.md) e a [Política de Privacidade](./PRIVACY_POLICY.md).

---

## 2. Versão Resumida (footer obrigatório em ReportDetail)

```
Laudo elaborado com apoio de inteligência artificial.

O texto gerado é MINUTA AUTOMATIZADA e pode conter erros,
omissões ou conclusões inadequadas. Revise integralmente,
valide clinicamente e edite antes de assinar ou entregar.

Você, médico, mantém responsabilidade profissional pelo laudo final.
Não use esta saída sem revisão médica completa.

Em conformidade com a Resolução CFM 2.314/2022 (Telemedicina)
e demais normas vigentes do Conselho Federal de Medicina.
```

> **Nota de UI:** o emoji ⚠️ não está no texto legal final por recomendação da revisão jurídica. Use o ícone visual `exclamationmark.triangle.fill` (SF Symbol) à esquerda do bloco, separado do texto.

**Especificação visual:**
- Não-dispensável (sem botão "fechar"/"ocultar");
- Fundo `SemanticColor.warningBg` (#FFFBEB), borda `warningBorder` (#FDE68A), texto `warningText` (#B45309);
- Ícone `exclamationmark.triangle.fill`;
- Sempre visível no rodapé do ReportDetail, abaixo do texto do laudo;
- Tamanho: `TextStyle.caption` (12pt Inter Regular).

---

## 3. Versão Curta (telas com pouco espaço)

Para uso em Generate, Login ou outros contextos onde o disclaimer completo não cabe:

```
Seus laudos são privados. Revise antes de assinar.
```

ou, alternativamente, quando contexto envolve IA:

```
Conteúdo gerado por IA. Revise antes de assinar.
```

---

## 4. Quando exibir cada versão

| Local | Versão | Frequência |
|---|---|---|
| **Modal de aceite inicial** (primeira vez que abre Generate logado) | Completa | 1× por Conta, com `terms_accepted_at` registrando o aceite |
| **Configurações → "Sobre o LaudoUSG"** | Completa | Sempre disponível para consulta |
| **ReportDetail** (laudo gerado) | Resumida | Sempre, no rodapé, não-dispensável |
| **Generate (tela principal)** | Curta | Sempre visível discretamente |
| **Login (footer)** | Curta | Já implementado |
| **Onboarding (Sprint 11)** | Resumida | Tela 2 de 3 do onboarding |

---

## 5. Implementação técnica (referência pro Sprint 11)

### 5.1 Estado de aceite

Tabela `public.profiles` já tem `terms_accepted_at: timestamp with time zone NULL`. **Para defensibilidade probatória**, recomenda-se registrar também:

- `terms_version_accepted` — versão dos Termos de Uso aceita
- `privacy_version_accepted` — versão da Política de Privacidade aceita
- `medical_disclaimer_version_accepted` — versão do Disclaimer Médico aceita
- Metadados técnicos mínimos do aceite, quando aplicável e proporcional (ex: user-agent, IP truncado), respeitando minimização

**Migration sugerida (Sprint 11):**

```sql
ALTER TABLE public.profiles
  ADD COLUMN terms_version_accepted text,
  ADD COLUMN privacy_version_accepted text,
  ADD COLUMN medical_disclaimer_version_accepted text;
```

**Quando o Usuário aceita** o Disclaimer + Termos + Privacy:

```typescript
UPDATE public.profiles
SET
  terms_accepted_at = NOW(),
  terms_version_accepted = $termsVersion,
  privacy_version_accepted = $privacyVersion,
  medical_disclaimer_version_accepted = $disclaimerVersion
WHERE id = $userId;
```

**Reaceite forçado** quando qualquer versão for atualizada (ex: v1.2 → v1.3): comparar `*_version_accepted` com versão vigente do app e, se divergir, exibir modal de novo aceite.

### 5.2 Gate de uso

```swift
// Em GenerateViewModel ou onAppear de GenerateView
if app.profile?.termsAcceptedAt == nil {
    // Exibir modal de aceite com versão completa
    presentDisclaimerModal()
}
```

### 5.3 Versionamento

Se o disclaimer for atualizado (versão 2.0), criar coluna `terms_version_accepted: text` em `profiles` e exigir novo aceite quando `terms_version_accepted < currentVersion`.

---

## 6. Notas para revisão jurídica e médica

### 6.1 Pontos que merecem atenção do advogado

- **Capítulo III do CEM (Art. 1º):** vedação ao médico de "deixar de assumir responsabilidade". O disclaimer reforça isso. Revisar se a redação está suficiente para limitar a responsabilidade do Controlador.
- **Norma específica do CFM sobre IA em medicina:** confirmar qual resolução está vigente em 2026 e inserir a referência correta (a CFM 2.272/2020 originalmente citada trata de cirurgia craniomaxilofacial, NÃO de IA — foi flag da revisão jurídica interna).
- **Equiparação a "fornecedor" no CDC:** apesar de ser ferramenta profissional, o CDC pode aplicar-se. Avaliar redação da limitação de responsabilidade.
- **Cláusula de não-substituição:** garantir que a redação ("LaudoUSG não realiza diagnóstico") é defensável em juízo se houver questionamento de exercício ilegal da medicina por pessoa jurídica.

### 6.2 Pontos que merecem atenção do médico revisor

- **Terminologia:** revisar se "proposta editorial" é o termo mais adequado ou se há expressão melhor (alternativas: "sugestão", "draft", "primeira versão");
- **Adequação à prática clínica:** confirmar se médicos ultrassonografistas reconhecem este disclaimer como justo e não-paternalista;
- **Cenários reais de risco:** se há cenário clínico específico onde o disclaimer deveria ser mais enfático (ex: laudos obstétricos com viabilidade fetal).

---

**Data de vigência desta versão:** 2026-05-18
**Versão:** 1.2
