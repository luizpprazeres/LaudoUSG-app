# iOS: preparação dos cinco modelos clínicos — 2026-10-02

Escopo: `ABDOMEN_TOTAL_DOPPLER`, `DOPPLER_VENOSO_MMSS`, `DOPPLER_ARTERIAL_MMSS`, `TORAX` e `QUADRIL_INFANTIL`, consumindo `POST /api/v1/clinical-reports` e `POST /api/v1/clinical-reports/{id}/review`. Fontes: `packages/shared/src/clinicalModels` (monorepo `0129786`), `docs/clinical-approval/2026-10-02-modelos-hepaticos-decisoes.md` e `docs/parity/decisoes-pendentes-2026-09-30.html`. Nada foi publicado no TestFlight.

## Estado do gate

- Release: os cinco ficam fora de `ReportCategory.selectable` e o `GenerateViewModel` recusa essas categorias (`PendingClinicalModelContracts.isRolloutEnabled == false`).
- Debug: só aparecem com `-ClinicalModelsV1Preview YES` nos argumentos do scheme, para QA local.
- Servidor: em 02/10/2026 a rota de produção respondeu `404 clinical_models_v1_unavailable` a uma chamada autenticada com corpo inválido (sem caminho de persistência). O gate do backend (`RENDERER_CATEGORIES` com os cinco códigos) segue OFF.

Para a liberação conjunta: trocar o `#else false` de `isRolloutEnabled`, atualizar `CategorySelectionTests`, regenerar a fixture e rodar a suíte.

## O que mudou

- **Paridade verificada contra o código do servidor.** `LaudoUSGTests/clinical-models-v1-golden.json` tem 41 casos (os 10 da revisão clínica + bordas e bloqueios) produzidos por `validateClinicalModelInput`/`renderClinicalModelReport` reais. `ClinicalModelsSharedParityTests` exige texto idêntico byte a byte, o mesmo resultado bloqueia/libera, os mesmos avisos e o mesmo payload JSON. O teste encontrou divergências no renderer Swift (fase da trombose ausente, frase do desfiladeiro torácico, linha de consolidação/atelectasia/pneumotórax e morfologia do quadril), já corrigidas.
- **Servidor como autoridade.** O espelho local serve só para pré-checagem; os códigos de bloqueio do abdome foram alinhados aos do servidor (`PORTAL_VEIN_REQUIRED`, `OPTIONAL_VESSEL_INCOMPLETE`). Os erros da API passam a ser legíveis e os `issues` de um 422 aparecem como vieram do servidor.
- **Envio normalizado.** Validação, prévia, envio e conferência da resposta usam a forma que o servidor persiste: ramos falsos sem campos órfãos e o mesmo `trim()` do Zod em textos e chaves. Antes, um espaço no fim de um campo ou um valor oculto depois de desmarcar um módulo fazia o app rejeitar a resposta válida do servidor.
- **Bilateralidade (decisão de 30/09: um laudo com seções direita e esquerda).** Venoso e arterial: o lado só é examinado se solicitado, o lado fora do pedido volta ao estado neutro e um lado examinado fora da lateralidade bloqueia (`SIDE_OUTSIDE_LATERALITY`). Tórax e quadril continuam sempre bilaterais, como no contrato.
- **Bloqueios clínicos na UI.** A confirmação de Graf deixa de valer quando idade, ângulos ou morfologia mudam a sugestão; antes, a classificação era trocada automaticamente e mantinha a confirmação. A fase da trombose é limpa quando a trombose deixa de existir; antes, o erro bloqueava sem campo visível para corrigir. A VPS do vaso afetado acompanha a renomeação e sai do laudo quando o resultado volta a normal.
- **Abdome com Doppler.** O texto-base é o `NORMAL_ABDOMEN_REPORT` do shared, já com "Não há sinais de processo expansivo hepático." Cada vaso avaliado sai pelo próprio nome, sem "Demais vasos avaliados".
- **Campos numéricos.** O campo antigo reformatava cada tecla ("1" virava "1,0"), o que impedia digitar decimais.
- **Ordem das VPS.** O envio usa chaves ordenadas para que o texto do servidor liste as VPS na mesma ordem da prévia.

## Rodada 2 — regras portais e fisiologia venosa hepática

Base: branch de backend `claude/five-models-parity` (`2399a23`/`b58ab06`) **mais alterações ainda não commitadas** daquele worktree. Por isso a fixture registra `sharedCommit: b58ab06-dirty`, e precisa ser regerada quando o backend commitar.

- `PORTAL_FINDING_STATUS_MISMATCH`: situação portal "ausente" com tipo, critérios ou confirmação preenchidos bloqueia. Ao voltar a situação para "ausente", a UI limpa esses campos (`PortalPathology.settingStatus`), que ficam ocultos e, mantidos, bloqueariam sem caminho de correção.
- `ABNORMAL_FLOW_WITHOUT_PORTAL_FINDING`: com situação portal "ausente", qualquer vaso avaliado com fluxo ausente, "outro" ou de direção não fisiológica bloqueia, porque a conclusão afirmaria normalidade.
- Fisiologia (`AbdomenTotalDopplerDraft.physiologicalFlow`, espelho de `PHYSIOLOGICAL_FLOW_DIRECTION`): **veias hepáticas hepatofugais**; tronco portal, esplênica, mesentérica superior e artéria hepática comum hepatopetais. Os seletores marcam a direção fisiológica do vaso, sem pré-selecionar valor.
- Renderer: texto livre (critérios portais, padrão distal, limitação do tórax) termina com um único ponto, como `sentence()` do shared; suspeita de alteração portal "outra" vira "Achados suspeitos de alteração do sistema portal, conforme descritos acima."
- Fixture: 68 casos. Nenhum caso aceito como normal tem fluxo fora da fisiologia (teste `testNoNormalCaseAcceptsNonPhysiologicalFlow`). O caso alterado que usava veias hepáticas hepatopetais passou a usar o fluxo fisiológico. Os rascunhos iniciais não pré-selecionam direção de fluxo.

## Regenerar a fixture

```bash
(cd ~/laudousgmobile-def/packages/shared && tsx "$OLDPWD/docs/parity/tools/generate-clinical-models-golden.ts") \
  > LaudoUSGTests/clinical-models-v1-golden.json
# Para gerar de outro worktree do backend: MONOREPO=/caminho/do/worktree antes do tsx.
```

## Lacunas da API (não resolvidas no iOS)

1. **Lateralidade não é validada no servidor.** `validateClinicalModelInput` não rejeita lado `examined: true` fora de `laterality` (MMSS), e o renderer imprime qualquer lado examinado. O iOS bloqueia localmente, mas Web e Android dependem da própria UI.
2. **Concordância no texto do tórax.** O renderer compartilhado gera "Sinais de pneumotórax: não identificada." e "pneumotórax suspeita/confirmada". O iOS reproduz o texto do servidor para manter a paridade; a correção precisa sair no `renderer.ts`, com revisão clínica, e depois na fixture.
3. **Sem sinal de capacidade.** O cliente só descobre o gate do servidor pelo 404; não há flag remota para ligar a categoria no app sem nova build.
4. **Ordem de `psvCms`.** O texto depende da ordem de inserção das chaves no JSON. Um cliente que envie outra ordem gera outro texto para o mesmo contrato.

## Pendência do iOS

- **Retomada após fechar o app.** Por decisão anterior, o rascunho persistido descarta o vínculo com o laudo remoto (`draftForPersistence`). Depois de reabrir o app, aprovar exige novo `POST`, ou seja, um novo laudo no histórico. `GET /api/reports/{id}` já expõe `content_revision` e `structured_findings`, então a retomada sem duplicar o laudo pode ser feita no cliente.

## Validação

- Rodada 1: `xcodebuild test` (iPhone 17, iOS Simulator), 148 testes, 0 falhas, 3 ignorados já existentes (tabela OMS do Hadlock); build Release para o Simulator com sucesso.
- Rodada 2: 152 testes, 0 falhas, os mesmos 3 ignorados; golden parity com 68 casos; build Release para o Simulator e para dispositivo genérico (sem assinatura) com sucesso.
- Sem teste em dispositivo físico, sem teste E2E contra o servidor com o gate ligado e sem revisão clínica nova.
