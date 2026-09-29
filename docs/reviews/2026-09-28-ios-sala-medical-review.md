# Revisão médica explícita antes da Sala — iOS

Implementação no app Swift principal; o projeto `LaudoUSG-watch` e o backend não foram alterados.

## Fluxo entregue

- A ação **“Revisado — liberar para Sala”** está disponível no laudo recém-gerado e no detalhe do histórico. O botão legado **“Enviar p/ Sala”** continua separado e não concede nem representa aprovação médica.
- Ao aprovar, o app cancela e aguarda o autosave pendente, grava o texto atual e busca novamente o detalhe por `GET /api/reports/:id`.
- O app exige `content_revision` e igualdade exata entre o texto persistido (`final_output`, ou `generated_output` quando não há final) e o texto visível. Sem igualdade ou versão, a solicitação não é enviada.
- A chamada autenticada usa `POST /api/reports/:id/review` com JSON camelCase `{ "expectedRevision": number, "expectedText": string }`. O texto esperado não é escrito em logs pelo cliente.
- Só uma resposta coerente (`ok`, mesma `contentRevision`, `reviewStatus: "reviewed"` e `reviewedAt`) marca a versão como revisada localmente. HTTP 409 pede conferir o laudo atualizado e revisar novamente.
- Qualquer edição limpa imediatamente o estado local de revisão. A invalidação persistida depende do trigger backend descrito na auditoria; este trabalho não muda nem valida esse trigger.
- Relatórios legados sem os campos novos continuam decodificáveis como não confirmados. O app não deriva aprovação de envio antigo, `updated_at` ou status de geração.

## Contrato e dependências

O detalhe precisa devolver `content_revision` dentro do objeto `report`. A resposta de POST precisa obedecer ao contrato acima. A operação exige sessão JWT aceita pelo backend e permissão médica; o app não substitui a autorização do servidor. Se o contrato/servidor ainda não estiver implantado, o fluxo apresenta erro e não mostra a versão como revisada.

O endpoint deverá fazer a comparação de versão e texto atomicamente e responder 409 quando a versão esperada não for mais atual. Proteção contra gravações concorrentes após a aprovação depende da invalidação no banco descrita na auditoria.

## Verificação

`xcodebuild build` passou. O gate direcionado de contratos e política de consentimento passou 6/6; `ReportReviewContractTests` passou 4/4. A suíte completa compilou app e testes e executou 97 testes: 92 passaram, 3 foram ignorados e 2 falharam em `ImageAnalysisServiceTests` (`testObstetricImageCanCombineBiometryAndDoppler`, linha 45; `testStandaloneDopplerFormatsResistanceAndPulsatilityWithoutBiometry`, linhas 22 e 24). Esses arquivos não foram alterados nesta tarefa; o estado baseline não foi reexecutado. O build emitiu warnings Swift concurrency preexistentes em `AppleSpeechLiveService`, `DeepgramLiveService` e `ConsultorSheet`. Não houve commit, push, publicação ou alteração em serviço remoto.
