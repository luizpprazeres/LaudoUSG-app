# REVISÃO JURÍDICA — LaudoUSG Sprint 11
## Parecer da advogada Dra. Helena Duarte

Nota de escopo: reli integralmente os três documentos atuais. Não reabri pesquisa normativa externa nesta rodada porque o pedido limitou a atividade à leitura dos três `.md`. Portanto, onde houver norma setorial de IA/CFM em evolução, mantenho a recomendação de confirmação humana especializada antes de produção.

## TERMS_OF_USE.md

## TERMS_OF_USE.md — Issue P1 #1

**Localização:** Status dos dados de identificação; Seção 1, primeiro parágrafo.

**Problema:** “CNPJ em andamento via INPI” é tecnicamente incorreto. INPI não emite CNPJ. Isso fragiliza credibilidade documental e pode gerar questionamento em App Review, consumidor ou contrato.

**Substituição recomendada:**
```
- ⏳ **CNPJ:** pessoa jurídica em constituição — atualizar quando houver inscrição emitida pela Receita Federal
```

E substituir, na Seção 1:
```
Estes Termos de Uso ("Termos") regulam o acesso e uso do aplicativo **LaudoUSG** ("Aplicativo", "Serviço", "LaudoUSG") fornecido por **Luiz Paulo de Souza Prazeres**, CPF 108.964.194-20 (Pessoa Física — pessoa jurídica em constituição), com endereço de contato postal fornecido mediante solicitação ao Encarregado de Dados (DPO) pelo email contato@laudousg.com ("Controladora", "nós").
```

## TERMS_OF_USE.md — Issue P1 #2

**Localização:** Seção 3, último parágrafo.

**Problema:** A cláusula fala em encerramento sem aviso prévio por CRM inválido, mas não prevê direito de contestação/correção. Em relação de consumo e em contexto profissional regulado, é melhor prever suspensão preventiva e chance razoável de regularização, salvo fraude ou risco.

**Substituição recomendada:**
```
A Controladora reserva-se o direito de verificar a validade do CRM e da UF informados junto a bases públicas ou canais oficiais dos Conselhos de Medicina. Caso sejam identificados indícios de informação falsa, desatualizada ou incompatível, a Conta poderá ser suspensa preventivamente e o Usuário poderá ser solicitado a corrigir ou comprovar os dados. A Controladora poderá encerrar a Conta sem aviso prévio apenas em caso de fraude, uso por não médico, risco à segurança, determinação legal/regulatória ou ausência de regularização em prazo razoável.
```

## TERMS_OF_USE.md — Issue P1 #3

**Localização:** Seção 4.3, último parágrafo sobre “Sala do Auxiliar”.

**Problema:** A Sala do Auxiliar cria acesso por terceiro a conteúdo clínico. Falta impor ao médico dever de sigilo, autorização e supervisão sobre auxiliar. Sem isso, a Controladora fica exposta em incidente de confidencialidade gerado por pessoa convidada pelo usuário.

**Substituição recomendada:**
```
O LaudoUSG oferece o recurso **"Sala do Auxiliar"** como forma autorizada de compartilhamento temporário de sessões de laudo com auxiliares de consultório. O Usuário titular permanece responsável por autorizar, supervisionar e encerrar esse acesso, bem como por garantir que o auxiliar esteja vinculado à sua rotina profissional, atue sob dever de confidencialidade e acesse apenas o conteúdo necessário para a execução da atividade delegada. O compartilhamento da sessão não transfere ao auxiliar responsabilidade técnica pelo laudo nem reduz a responsabilidade profissional do médico Usuário.
```

## TERMS_OF_USE.md — Issue P1 #4

**Localização:** Seção 7, itens 2 e 5.

**Problema:** “A IA não realiza diagnóstico” é defensável como tese, mas incompleto: a IA pode redigir conclusão diagnóstica. A defesa mais robusta é dizer que ela não toma decisão médica; qualquer conclusão é minuta/sugestão textual.

**Substituição recomendada:**
```
2. **A IA não toma decisão diagnóstica, terapêutica ou prognóstica**, não pratica medicina e não substitui o julgamento do médico. Quando o sistema redigir hipóteses, conclusões ou formulações diagnósticas, elas constituem apenas minuta automatizada de texto, sujeita à revisão e validação integral pelo Usuário médico;
```

Substituir o item 5 por:
```
5. **O LaudoUSG não assume a responsabilidade profissional pelo laudo final assinado pelo Usuário**, sem prejuízo de eventual responsabilidade da Controladora por defeito próprio do Serviço, falha de segurança, informação insuficiente, descumprimento legal ou outras hipóteses de responsabilidade não excluíveis por lei.
```

## TERMS_OF_USE.md — Issue P1 #5

**Localização:** Seção 8.3, lista de finalidades da licença.

**Problema:** “Melhorar o produto, mediante agregação e anonimização” é aceitável, mas precisa deixar claro que não autoriza treinar modelos de IA com conteúdo clínico identificável ou individualizável. Esse é ponto sensível em saúde e App Store.

**Substituição recomendada:**
```
Para operar o Serviço, o Usuário concede à Controladora licença **não-exclusiva, gratuita, limitada e revogável nos termos da legislação aplicável** para **armazenar, processar, transmitir e exibir** o Conteúdo do Usuário, exclusivamente na medida necessária para:

- Prestar o Serviço solicitado pelo Usuário;
- Manter histórico, preferências e funcionalidades da Conta;
- Cumprir obrigações legais, regulatórias ou ordens de autoridade competente;
- Produzir métricas estatísticas agregadas e anonimizadas para segurança, desempenho e melhoria do produto.

Esta licença **não inclui** o direito de vender, divulgar, comercializar ou tornar público o Conteúdo do Usuário. O Conteúdo do Usuário não será usado para treinar modelos de IA de terceiros ou modelos próprios com dados identificáveis ou individualizáveis, salvo se houver base legal específica, informação prévia adequada e, quando exigível, consentimento ou autorização válida.
```

## TERMS_OF_USE.md — Issue P1 #6

**Localização:** Seção 9, Planos e Pagamento.

**Problema:** A redação futura de billing é genérica e não cobre Apple IAP/subscriptions. Antes de billing, será necessário adequar a Apple §3.1. Se permanecer como “nota futura”, deve evitar promessa de cobrança fora da Apple.

**Substituição recomendada:**
```
> **NOTA:** funcionalidade de planos pagos ainda não implementada na versão atual.

A Controladora poderá oferecer planos pagos no futuro. Quando disponíveis, as condições comerciais serão informadas de forma clara antes da contratação, incluindo preço, periodicidade, renovação, cancelamento, impostos aplicáveis e eventuais limitações de uso. Em ambiente iOS, assinaturas, compras digitais e recursos pagos serão implementados conforme as regras vigentes da Apple App Store, incluindo, quando aplicável, uso de compras dentro do app e disponibilização das informações exigidas pela Apple para assinaturas renováveis.

Enquanto planos pagos não estiverem implementados, nenhuma cláusula destes Termos deve ser interpretada como autorização para cobrança recorrente.
```

## TERMS_OF_USE.md — Issue P1 #7

**Localização:** Seção 10.1, suspensão e encerramento pela Controladora.

**Problema:** “com ou sem aviso prévio” é amplo demais. Melhor separar suspensão imediata em risco/fraude e aviso quando possível. Isso reduz risco de abusividade.

**Substituição recomendada:**
```
A Controladora poderá suspender ou encerrar a Conta do Usuário nas hipóteses abaixo. Sempre que razoavelmente possível, a Controladora comunicará o Usuário e permitirá regularização. A suspensão ou encerramento poderá ocorrer sem aviso prévio quando houver risco à segurança, fraude, uso por pessoa não autorizada, violação grave destes Termos, determinação judicial/regulatória ou risco relevante a terceiros.

- Violação destes Termos;
- Suspeita fundada de fraude, uso indevido ou conduta ilícita;
- Cadastro com dados falsos, CRM inválido ou uso por pessoa não médica;
- Risco à segurança do Serviço, de outros Usuários ou de terceiros;
- Decisão judicial;
- Determinação regulatória.
```

## TERMS_OF_USE.md — Issue P1 #8

**Localização:** Seção 11, após lista de responsabilidades do médico.

**Problema:** Falta cláusula de não uso em contexto crítico. Para defesa judicial, é relevante demonstrar que o app delimitou cenários inadequados.

**Substituição recomendada:**
```
O Usuário não deve utilizar o LaudoUSG como única base para decisões clínicas, nem em situações em que não possa revisar integralmente o conteúdo antes de assinar. O LaudoUSG não deve ser usado para substituir avaliação médica direta, tomada de decisão em urgência ou emergência, condução de paciente instável, comunicação de diagnóstico grave sem mediação humana, ou qualquer situação em que a qualidade do ditado, do áudio, das informações disponíveis ou do contexto clínico impeça validação médica segura.
```

## TERMS_OF_USE.md — Issue P1 #9

**Localização:** Seção 13, Indenização.

**Problema:** “indenizar e isentar” pode ser visto como renúncia ampla de direitos e tentativa de transferir integralmente responsabilidade. Melhor limitar a atos do usuário e ressalvar responsabilidade própria da Controladora.

**Substituição recomendada:**
```
O Usuário concorda em indenizar a Controladora por perdas, danos, custos e despesas razoáveis decorrentes de ato ou omissão imputável ao Usuário, incluindo:

- Violação destes Termos pelo Usuário;
- Uso indevido do LaudoUSG;
- Inserção de dados de pacientes em violação às regras de uso;
- Violação de direitos de terceiros pelo Usuário;
- Imperícia, imprudência ou negligência médica do Usuário;
- Uso da Conta por terceiros autorizados ou facilitados pelo Usuário, incluindo auxiliares.

Esta cláusula não exclui nem limita eventual responsabilidade própria da Controladora por defeito do Serviço, falha de segurança, descumprimento de obrigações legais ou outras hipóteses de responsabilidade não excluíveis por lei.
```

## TERMS_OF_USE.md — Issue P2 #10

**Localização:** Seção 15, Modificações dos Termos.

**Problema:** Uso continuado como aceitação é frágil para mudanças materiais. Melhor exigir aceite expresso para temas sensíveis.

**Substituição recomendada:**
```
A Controladora poderá modificar estes Termos periodicamente. Modificações materiais serão comunicadas:

- Por email cadastrado, com antecedência mínima de **15 (quinze) dias**, quando aplicável;
- Por banner ou aviso no Aplicativo;
- Com atualização da data de "Última atualização" no topo destes Termos.

Alterações relevantes sobre tratamento de dados pessoais, uso de inteligência artificial, responsabilidades médicas, funcionalidades pagas, limitação de responsabilidade ou compartilhamento com terceiros poderão exigir novo aceite expresso. Caso o Usuário não concorde com a nova versão, deverá interromper o uso do Serviço e poderá solicitar encerramento da Conta.
```

## TERMS_OF_USE.md — Issue P2 #11

**Localização:** Seção 18, Contato.

**Problema:** Mesmo email para tudo é aceitável no MVP, mas ideal separar canal de suporte e privacidade. Como redação pronta, já deixa estrutura para alias.

**Substituição recomendada:**
```
Dúvidas, sugestões ou solicitações relacionadas a estes Termos:

- **Suporte e comunicações gerais:** contato@laudousg.com
- **Privacidade e proteção de dados:** contato@laudousg.com ou dpo@laudousg.com, quando disponível
- **Endereço postal:** fornecido mediante solicitação ao Encarregado de Dados, observado o uso de endereço comercial quando houver pessoa jurídica constituída
```

## TERMS_OF_USE.md — Cláusulas FALTANDO que recomendo adicionar

## TERMS_OF_USE.md — Cláusula nova recomendada #1

**Localização:** Inserir após Seção 7.

**Problema:** Falta cláusula de transparência sobre IA, paciente e prontuário. Não é UX; é obrigação de alocação regulatória ao médico usuário.

**Substituição recomendada:**
```
## 7-A. Transparência no Uso de IA pelo Usuário Médico

O Usuário reconhece que normas profissionais e regulatórias podem exigir transparência sobre o uso de ferramentas de inteligência artificial em contexto assistencial. Quando aplicável à sua prática, ao tipo de atendimento, ao prontuário ou à relação médico-paciente, o Usuário é responsável por:

- Informar o paciente ou responsável legal, de forma clara e adequada, quando a IA tiver sido usada como apoio relevante na elaboração do laudo;
- Registrar no prontuário ou sistema equivalente o uso de ferramenta de IA como apoio, quando exigido por norma aplicável ou boa prática institucional;
- Preservar sua autonomia profissional e não seguir automaticamente qualquer sugestão gerada pelo LaudoUSG;
- Respeitar eventual recusa informada do paciente quanto ao uso de IA, quando juridicamente aplicável.

A Controladora disponibiliza o LaudoUSG como ferramenta de apoio à redação e organização do laudo, mas não substitui os deveres éticos, assistenciais, informacionais e documentais do Usuário médico.
```

## TERMS_OF_USE.md — Cláusula nova recomendada #2

**Localização:** Inserir após Seção 5.2 ou dentro da Seção 5.

**Problema:** Falta tratamento contratual para inserção acidental/proibida de dado de paciente.

**Substituição recomendada:**
```
### 5.4 Inserção Indevida de Dados de Pacientes

Caso o Usuário insira dados identificáveis de pacientes em violação a estes Termos, deverá interromper o uso desse conteúdo, removê-lo quando possível e comunicar a Controladora se houver risco relevante à privacidade, segurança ou direitos do titular. A Controladora poderá remover, bloquear ou anonimizar conteúdo que identifique paciente, quando tecnicamente possível e juridicamente adequado, sem que isso implique obrigação de monitoramento prévio de todos os conteúdos inseridos pelo Usuário.

O Usuário permanece responsável por cumprir seus deveres como médico e controlador primário dos dados do paciente, incluindo informação ao titular, base legal, sigilo profissional, registro em prontuário e atendimento a solicitações do paciente ou autoridades competentes.
```

## PRIVACY_POLICY.md

## PRIVACY_POLICY.md — Issue P1 #1

**Localização:** Status dos dados de identificação; Seção 1 e Seção 2.

**Problema:** Mesmo problema de CNPJ/INPI e identificação do controlador. Além disso, “Controladora” no feminino pode ser mantido como entidade do app, mas pessoa física é “Controlador”. Escolha um padrão.

**Substituição recomendada:**
```
Esta Política de Privacidade ("Política") descreve como **Luiz Paulo de Souza Prazeres** ("LaudoUSG", "nós", "Controlador"), CPF 108.964.194-20 (Pessoa Física — pessoa jurídica em constituição), coleta, utiliza, compartilha e protege os dados pessoais dos usuários do aplicativo **LaudoUSG**.
```

Substituir a Seção 2 por:
```
## 2. Quem somos (Controlador)

**Controlador dos dados:** Luiz Paulo de Souza Prazeres  
**CPF:** 108.964.194-20  
**Natureza atual:** Pessoa Física, com pessoa jurídica em constituição  
**Email institucional:** contato@laudousg.com  
**Endereço postal:** fornecido mediante solicitação ao Encarregado de Dados, observado o uso de endereço comercial quando houver pessoa jurídica constituída

**Encarregado de Proteção de Dados (DPO):**
- **Nome:** Luiz Paulo de Souza Prazeres
- **Email:** contato@laudousg.com ou dpo@laudousg.com, quando disponível
```

## PRIVACY_POLICY.md — Issue P1 #2

**Localização:** Seção 4.2, tabela “Conteúdo Produzido pelo Usuário”.

**Problema:** Falta base legal de dados sensíveis para conteúdo clínico quando identificável ou quando revele saúde. Mesmo com proibição de identificação, achados/laudos podem ser dado de saúde se conectados a paciente. Precisamos deixar base LGPD Art. 11 condicionada/incidental, sem afirmar consentimento inexistente.

**Substituição recomendada:**
```
### 4.2 Conteúdo Produzido pelo Usuário (durante uso)

| Dado | Finalidade | Base Legal |
|---|---|---|
| Texto digitado/ditado de achados | Geração de minuta de laudo | Execução de contrato com o Usuário (Art. 7º, V). Quando o conteúdo revelar dado de saúde identificável por inserção indevida do Usuário, o tratamento ocorrerá de forma incidental e restrita à prestação do serviço solicitado, observadas as hipóteses aplicáveis do Art. 11 da LGPD sob responsabilidade primária do Usuário médico |
| Áudio gravado (temporário) | Transcrição via Whisper | Execução de contrato com o Usuário (Art. 7º, V). Se houver dado de saúde identificável inserido no áudio, aplica-se a mesma regra de tratamento incidental e restrito acima |
| Laudos gerados | Armazenamento no histórico do Usuário | Execução de contrato com o Usuário (Art. 7º, V). O Usuário é instruído a não inserir dados identificáveis de pacientes |
| Frases customizadas | Reutilização pelo Usuário | Execução de contrato (Art. 7º, V) |
| Configurações (estilo, idioma) | Personalização | Execução de contrato (Art. 7º, V) |

**Áudio:** o arquivo de áudio é enviado para transcrição e descartado após o processamento, conforme a arquitetura do Serviço. O LaudoUSG não disponibiliza funcionalidade para armazenamento permanente de áudios pelo Usuário.
```

## PRIVACY_POLICY.md — Issue P1 #3

**Localização:** Seção 5, “Dados que NÃO Coletamos”.

**Problema:** A redação absoluta “NÃO coleta dados identificáveis de pacientes” conflita com risco incidental. Precisa virar compromisso de design e proibição contratual, não declaração absoluta impossível.

**Substituição recomendada:**
```
## 5. Dados que NÃO Devem Ser Inseridos no LaudoUSG

O LaudoUSG foi desenhado para operar com minimização de dados e **não exige** dados identificáveis de pacientes para funcionar. Os Termos de Uso proíbem que o Usuário insira:

- Nome, CPF, RG, endereço, telefone, email, foto, número de prontuário ou qualquer identificador direto de paciente;
- Imagens médicas, incluindo ultrassonografias ou outros exames de imagem;
- Dados de terceiros sem base legal ou autorização aplicável.

Caso o Usuário descumpra essa orientação e insira dados identificáveis de pacientes, tal tratamento será considerado indevido em relação às regras do Serviço e será tratado, quando detectado, conforme medidas de mitigação, bloqueio, exclusão ou anonimização tecnicamente possíveis.

O LaudoUSG também não coleta intencionalmente:

- Localização geográfica precisa do Usuário;
- Contatos, calendário ou biblioteca de fotos do dispositivo;
- Identificadores publicitários (Apple IDFA);
- Dados biométricos do Usuário;
- Dados para rastreamento publicitário, perfilhamento para marketing de terceiros, fingerprinting ou web tracking.
```

## PRIVACY_POLICY.md — Issue P1 #4

**Localização:** Seção 6, item 3.

**Problema:** “De terceiros: NÃO coletamos dados de fontes terceiras” conflita com possível validação de CRM junto a conselhos, Resend/Apple/Supabase logs e operadores. Melhor restringir.

**Substituição recomendada:**
```
3. **De terceiros ou fontes públicas:** quando necessário para validar informações cadastrais fornecidas pelo Usuário, como CRM e UF, ou para receber dados técnicos de operadores necessários à segurança, autenticação, entrega de emails transacionais, distribuição do app e funcionamento do Serviço.
```

## PRIVACY_POLICY.md — Issue P1 #5

**Localização:** Seção 7, “Melhorias do produto”.

**Problema:** “Melhorias do produto” pode ser interpretado como uso amplo de conteúdo clínico para treinamento. Precisa vedação expressa.

**Substituição recomendada:**
```
- **Melhorias do produto:** análise estatística agregada e anonimizada sobre desempenho, estabilidade, categorias utilizadas e fluxos de uso, sem identificação do Usuário ou de pacientes e sem uso de conteúdo clínico identificável para treinamento de modelos de IA;
```

E substituir o parágrafo final por:
```
**Não utilizamos** dados pessoais para marketing comportamental, perfilhamento, venda a terceiros ou treinamento de modelos de IA de terceiros com conteúdo identificável ou individualizável.
```

## PRIVACY_POLICY.md — Issue P1 #6

**Localização:** Seção 8, lista de operadores.

**Problema:** Apple aparece como operadora para “push notifications (futuro)”, mas funcionalidade futura não deve constar como tratamento atual se não existe. Também falta distinguir operadores atuais e futuros.

**Substituição recomendada:**
```
Para operar o Serviço, contratamos provedores que podem atuar como operadores ou suboperadores, processando dados conforme instruções, contratos e finalidades descritas nesta Política:

| Operador | Função | Local de processamento | Dados |
|---|---|---|---|
| **Supabase** | Banco de dados, autenticação e armazenamento | EUA (AWS us-east-1) ou região informada pelo fornecedor | Dados cadastrais, conteúdo do Usuário, autenticação, logs |
| **Vercel** | Hospedagem do backend | EUA / multi-região, conforme infraestrutura do fornecedor | Requisições, logs técnicos, dados processados pelo backend |
| **OpenAI** | Transcrição de áudio e geração de texto | Conforme termos e infraestrutura do fornecedor | Áudio temporário, texto do ditado e conteúdo necessário à geração |
| **Groq** | Fallback de geração de texto | Conforme termos e infraestrutura do fornecedor | Texto do ditado e conteúdo necessário à geração |
| **Resend** | Envio de emails transacionais | EUA / Europa, conforme infraestrutura do fornecedor | Email, metadados de envio e conteúdo do email |
| **Apple** | Distribuição do app e serviços da plataforma iOS | Global, conforme termos da Apple | Dados técnicos e de distribuição tratados pela Apple como provedora da plataforma |

Funcionalidades futuras, como push notifications, analytics adicionais ou billing, deverão ser refletidas nesta Política antes de entrarem em produção, quando envolverem novos dados, operadores ou finalidades.
```

## PRIVACY_POLICY.md — Issue P1 #7

**Localização:** Seção 8, obrigações dos operadores.

**Problema:** “Todos os Operadores são contratualmente obrigados...” só deve ficar se você tem DPA/contratos aplicáveis. Como nem sempre SaaS tem contrato negociado, prefira “buscamos contratar/aderir a termos”.

**Substituição recomendada:**
```
A Controladora busca utilizar fornecedores que disponibilizem termos, políticas, acordos de tratamento de dados ou mecanismos contratuais compatíveis com proteção de dados, segurança da informação e confidencialidade. Sempre que aplicável, tais fornecedores devem tratar dados apenas para as finalidades contratadas, adotar medidas técnicas e organizacionais adequadas e não vender dados pessoais tratados em nome do LaudoUSG.
```

## PRIVACY_POLICY.md — Issue P1 #8

**Localização:** Seção 9, Transferência Internacional.

**Problema:** A redação assume cláusulas contratuais padrão sem comprovar. Melhor usar “mecanismos disponíveis/contratos de adesão/DPA” e deixar compromisso de revisão.

**Substituição recomendada:**
```
## 9. Transferência Internacional de Dados

Alguns fornecedores podem armazenar ou processar dados fora do Brasil, incluindo Estados Unidos e outras regiões indicadas em seus termos. Essas transferências são realizadas para viabilizar a prestação do Serviço e devem observar os mecanismos previstos na LGPD, incluindo, conforme aplicável:

- Cláusulas contratuais, termos de processamento de dados ou documentos equivalentes disponibilizados pelos fornecedores;
- Medidas técnicas e organizacionais de segurança;
- Avaliação de compatibilidade entre a finalidade do tratamento, a natureza dos dados e as garantias oferecidas pelo fornecedor;
- Outras hipóteses de transferência internacional admitidas pela LGPD e regulamentação aplicável.

O Usuário pode solicitar informações adicionais sobre fornecedores e garantias aplicáveis pelo email contato@laudousg.com.
```

## PRIVACY_POLICY.md — Issue P1 #9

**Localização:** Seção 10, linha “Dados necessários a defesa em processos”.

**Problema:** Prazo “até trânsito em julgado + prescrição” é amplo e confuso. Melhor associar a exercício regular de direitos e retenção mínima necessária.

**Substituição recomendada:**
```
| Dados necessários ao exercício regular de direitos | Pelo prazo necessário à preservação de direitos, defesa em processos administrativos, judiciais ou arbitrais, e observados os prazos prescricionais aplicáveis | Exercício regular de direitos e cumprimento de obrigação legal |
```

## PRIVACY_POLICY.md — Issue P1 #10

**Localização:** Seção 11, direitos do titular.

**Problema:** Falta direito de petição à ANPD no rol do Art. 18. Ele aparece depois, mas deve entrar no rol.

**Substituição recomendada:**
```
Você tem direito a, a qualquer momento e mediante requisição:

1. **Confirmação** da existência de tratamento de dados;
2. **Acesso** aos seus dados;
3. **Correção** de dados incompletos, inexatos ou desatualizados;
4. **Anonimização, bloqueio ou eliminação** de dados desnecessários, excessivos ou tratados em desconformidade;
5. **Portabilidade** dos dados a outro fornecedor, mediante requisição expressa e observados segredos comercial e industrial;
6. **Eliminação** dos dados pessoais tratados com consentimento, quando aplicável, exceto hipóteses legais de retenção;
7. **Informação** sobre entidades públicas e privadas com as quais compartilhamos dados;
8. **Informação** sobre a possibilidade de não fornecer consentimento e as consequências;
9. **Revogação do consentimento**, quando o tratamento se basear em consentimento;
10. **Oposição** ao tratamento realizado em desconformidade com a LGPD;
11. **Revisão** de decisões automatizadas que afetem seus interesses, quando aplicável;
12. **Petição** perante a Autoridade Nacional de Proteção de Dados (ANPD).
```

## PRIVACY_POLICY.md — Issue P1 #11

**Localização:** Seção 11, prazo de resposta.

**Problema:** “15 dias úteis” pode ser mais oneroso do que necessário e talvez divergente de redação legal/regulatória. Como política pública, pode manter como compromisso, mas deixar possibilidade de complexidade e confirmação de identidade.

**Substituição recomendada:**
```
**Prazo de resposta:** responderemos às solicitações em prazo compatível com a LGPD e regulamentação aplicável, em regra em até **15 (quinze) dias**, contados da confirmação da identidade do solicitante e da clareza do pedido. Solicitações complexas, incompletas ou que envolvam dados de terceiros poderão exigir informações adicionais.
```

## PRIVACY_POLICY.md — Issue P1 #12

**Localização:** Seção 12, Segurança dos Dados.

**Problema:** Afirmações técnicas absolutas como TLS 1.3, AES-256 e bcrypt podem ser falsas parcialmente dependendo de fornecedor/configuração. Melhor tornar tecnicamente defensável.

**Substituição recomendada:**
```
Aplicamos e exigimos de nossos fornecedores medidas técnicas e organizacionais compatíveis com o risco do tratamento, incluindo, conforme aplicável:

- Criptografia em trânsito nas comunicações entre App, backend e fornecedores;
- Criptografia em repouso ou controles equivalentes de segurança nos ambientes de armazenamento;
- Autenticação por tokens de sessão e mecanismos de renovação/expiração;
- Row-Level Security (RLS) ou controles equivalentes de segregação de acesso no banco de dados;
- Armazenamento de senhas por mecanismos seguros de autenticação, sem manutenção de senha em texto claro pelo LaudoUSG;
- Monitoramento de acessos, logs técnicos e medidas de prevenção contra uso indevido;
- Backups regulares com retenção controlada;
- Restrição de acesso administrativo aos dados, limitado a necessidade operacional, suporte, segurança ou obrigação legal.
```

## PRIVACY_POLICY.md — Issue P2 #13

**Localização:** Seção 13, Cookies e Identificadores.

**Problema:** UserDefaults para JWT é detalhe técnico que pode assustar se não contextualizar. Também é melhor não afirmar “vinculado à Conta” para identificador de instalação se não estiver implementado.

**Substituição recomendada:**
```
Utilizamos:

- Tokens de autenticação armazenados localmente no dispositivo para manter a sessão do Usuário autenticada;
- Identificadores técnicos necessários para sessão, segurança, prevenção de fraude e funcionamento do app, quando aplicável.

Esses identificadores não são usados para publicidade, rastreamento entre apps/sites de terceiros ou venda de dados.
```

## PRIVACY_POLICY.md — Issue P2 #14

**Localização:** Seção 15, Decisões Automatizadas.

**Problema:** A redação é boa, mas a frase “direito de solicitar revisão dos critérios e processos do tratamento de dados por IA” pode prometer explicabilidade excessiva sobre modelos de terceiros. Ajustar para o que é viável.

**Substituição recomendada:**
```
A geração de texto por IA do LaudoUSG não constitui decisão automatizada final que produza efeitos jurídicos ou clínicos diretos sobre o Usuário ou paciente. A IA produz minuta ou sugestão de conteúdo, que deve ser revisada, editada e validada pelo médico Usuário antes de qualquer assinatura, entrega ou uso clínico.

Quando aplicável, o Usuário pode solicitar informações sobre a lógica geral, finalidades, limitações e papel da IA no Serviço, observados segredos comerciais, segurança, limitações técnicas de fornecedores e a legislação aplicável.
```

## PRIVACY_POLICY.md — Cláusulas FALTANDO que recomendo adicionar

## PRIVACY_POLICY.md — Cláusula nova recomendada #1

**Localização:** Inserir após Seção 8 ou após nova Seção 5.

**Problema:** Falta papel específico em caso de dado de paciente inserido indevidamente.

**Substituição recomendada:**
```
## 5-A. Tratamento Incidental de Dados de Pacientes

O LaudoUSG não solicita nem exige dados identificáveis de pacientes para prestar o Serviço. O Usuário médico é contratualmente orientado a anonimizar ou desidentificar os achados antes de inseri-los no Aplicativo.

Se, apesar dessa orientação, o Usuário inserir dados identificáveis de paciente, o tratamento poderá ocorrer de forma incidental e limitada ao processamento técnico necessário para prestar o Serviço solicitado, como transcrição, geração de minuta, armazenamento no histórico da Conta e segurança. Nessa hipótese:

- O Usuário médico permanece responsável por sua base legal, dever de sigilo profissional, informação ao paciente, registro em prontuário e demais obrigações perante o titular dos dados;
- O LaudoUSG adotará medidas razoáveis para limitar o tratamento à finalidade solicitada, proteger o dado e permitir exclusão, bloqueio ou anonimização quando tecnicamente possível;
- O LaudoUSG não usará dados identificáveis de pacientes para publicidade, venda, perfilhamento comercial ou treinamento de modelos de IA de terceiros.
```

## PRIVACY_POLICY.md — Cláusula nova recomendada #2

**Localização:** Inserir após Seção 11.

**Problema:** Falta procedimento sobre pedidos feitos por pacientes, que podem não ser usuários do app.

**Substituição recomendada:**
```
## 11-A. Solicitações Envolvendo Dados de Pacientes

Como o LaudoUSG não exige dados identificáveis de pacientes e a Conta pertence ao médico Usuário, solicitações feitas por pacientes ou terceiros poderão depender de informações adicionais para localização segura do dado e prevenção de acesso indevido. Quando a solicitação envolver conteúdo inserido por médico Usuário, poderemos orientar o titular a contatar o médico responsável e, quando juridicamente adequado, cooperar com a solicitação sem violar sigilo, segurança ou direitos de terceiros.
```

## MEDICAL_DISCLAIMER.md

## MEDICAL_DISCLAIMER.md — Issue P1 #1

**Localização:** Seção 1.1, bullet “proposta editorial”.

**Problema:** “Proposta editorial” é compreensível, mas juridicamente menos preciso para laudo médico. Melhor “minuta automatizada de laudo” ou “sugestão automatizada de redação clínica”.

**Substituição recomendada:**
```
- O conteúdo gerado pelo LaudoUSG é **minuta automatizada de laudo** ou **sugestão automatizada de redação clínica**, que requer **revisão crítica, edição quando necessária e validação clínica integral** por médico habilitado;
```

## MEDICAL_DISCLAIMER.md — Issue P1 #2

**Localização:** Seção 1.1, bullet “não realiza diagnóstico”.

**Problema:** O app pode redigir conclusão com aparência diagnóstica. A redação deve separar redação automatizada de decisão diagnóstica.

**Substituição recomendada:**
```
- O LaudoUSG **não toma decisão diagnóstica, terapêutica ou prognóstica**, não prescreve conduta, não substitui exame clínico nem avaliação direta do paciente. Qualquer hipótese, conclusão ou formulação diagnóstica eventualmente redigida pelo sistema é apenas sugestão textual sujeita à validação do médico Usuário.
```

## MEDICAL_DISCLAIMER.md — Issue P1 #3

**Localização:** Seção 1.2, lista “Suas responsabilidades”.

**Problema:** Falta dever de rejeitar integralmente a saída e dever de não usar se não houver revisão segura.

**Substituição recomendada:**
```
Como médico Usuário, você é o **único e final responsável** por:

- **Verificar a acurácia clínica** de todo conteúdo gerado pelo LaudoUSG;
- **Corrigir** erros, omissões, imprecisões terminológicas, interpretações inadequadas, medidas incorretas ou conclusões clinicamente incorretas;
- **Rejeitar integralmente** a minuta gerada sempre que ela não for compatível com os achados, o exame, o contexto clínico ou sua avaliação profissional;
- **Validar e assinar** o laudo final, assumindo responsabilidade profissional plena pelo conteúdo;
- **Comunicar adequadamente** os achados ao paciente ou ao médico solicitante, sem delegar essa comunicação à IA;
- **Não submeter** ao LaudoUSG dados identificáveis de pacientes (ver [Termos de Uso, Cláusula 5.2](./TERMS_OF_USE.md));
- **Cumprir** as normas do Conselho Federal de Medicina, do seu Conselho Regional, da instituição em que atua e a legislação aplicável.
```

## MEDICAL_DISCLAIMER.md — Issue P1 #4

**Localização:** Inserir após Seção 1.3.

**Problema:** Falta seção de quando não usar. Isso é muito relevante para defesa em erro médico.

**Substituição recomendada:**
```
#### 1.3-A Quando NÃO usar o LaudoUSG

Você não deve usar o LaudoUSG como única base para decisão clínica ou em situações nas quais não consiga revisar integralmente a saída antes de assinar. O LaudoUSG não deve ser usado:

- Em urgência, emergência, paciente instável ou situação tempo-dependente sem validação médica direta;
- Quando houver dúvida clínica relevante que exija reavaliação do exame, revisão de imagens, exame complementar ou discussão com outro profissional;
- Quando a qualidade do áudio, ditado, texto de entrada ou contexto clínico for insuficiente;
- Para comunicar diagnóstico, prognóstico ou conduta ao paciente sem mediação humana;
- Para substituir registro em prontuário, consentimento informado, sigilo profissional ou deveres éticos do médico;
- Quando o paciente ou a instituição recusar o uso de IA em contexto no qual tal recusa deva ser respeitada.
```

## MEDICAL_DISCLAIMER.md — Issue P1 #5

**Localização:** Seção 1.4, “O que o LaudoUSG NÃO faz”.

**Problema:** Repetir “não armazena dados identificáveis de pacientes” em absoluto é problemático. Melhor “não exige/veda”.

**Substituição recomendada:**
```
#### 1.4 O que o LaudoUSG NÃO faz

- **Não toma** decisão diagnóstica, terapêutica ou prognóstica;
- **Não substitui** o exame ultrassonográfico nem o juízo do médico examinador;
- **Não exige** dados identificáveis de pacientes para funcionar e **veda** que o Usuário insira esses dados;
- **Não armazena** imagens de ultrassonografia;
- **Não envia** o laudo ao paciente, ao SUS ou a qualquer sistema externo automaticamente;
- **Não comunica** diagnóstico, prognóstico ou conduta ao paciente;
- **Não pratica medicina**.
```

## MEDICAL_DISCLAIMER.md — Issue P1 #6

**Localização:** Seção 1.5, Conformidade regulatória.

**Problema:** Além de remover CFM 2.272/2020, a redação “desenvolvido em conformidade” é forte demais se ainda não houve auditoria jurídica/médica completa. Melhor “observa e deve ser usado em conformidade”.

**Substituição recomendada:**
```
#### 1.5 Conformidade regulatória

O LaudoUSG deve ser utilizado em conformidade com:

- **Resolução CFM 2.314/2022** — quando houver ato enquadrável como telemedicina ou uso de tecnologias digitais na assistência médica;
- **Norma vigente do CFM sobre uso de inteligência artificial em medicina**, a ser confirmada em revisão jurídica especializada antes da produção;
- **Código de Ética Médica** — Resolução CFM 2.217/2018, em especial:
  - **Capítulo III** (Responsabilidade Profissional): vedação ao médico de deixar de assumir responsabilidade por ato profissional;
  - **Capítulo IX** (Sigilo Profissional): obrigação de manter sigilo das informações de seus pacientes;
- **Lei Geral de Proteção de Dados** (Lei 13.709/2018);
- **Marco Civil da Internet** (Lei 12.965/2014).

O uso do LaudoUSG não afasta deveres éticos, assistenciais, documentais, informacionais ou de sigilo do médico Usuário.
```

## MEDICAL_DISCLAIMER.md — Issue P1 #7

**Localização:** Seção 2, Versão Resumida.

**Problema:** A versão resumida é boa, mas curta demais para defesa se não mencionar “minuta”, “pode omitir/inserir erro” e “não usar sem revisão integral”. Também tem referência errada à CFM 2.272/2020.

**Substituição recomendada:**
```
Laudo elaborado com apoio de inteligência artificial.

O texto gerado é minuta automatizada e pode conter erros,
omissões ou conclusões inadequadas. Revise integralmente,
valide clinicamente e edite antes de assinar ou entregar.

Você, médico, mantém responsabilidade profissional pelo laudo final.
Não use esta saída sem revisão médica completa.
```

Observação: para footer em UI, eu removeria o emoji “⚠️” do texto legal e deixaria o ícone visual por SF Symbol. Em documento markdown interno pode ficar, mas em texto jurídico final eu evitaria emoji.

## MEDICAL_DISCLAIMER.md — Issue P1 #8

**Localização:** Seção 3, Versão Curta.

**Problema:** “Seus laudos são privados. Revise antes de assinar” cobre privacidade, mas não cobre IA. Para telas de IA, precisa texto mais claro.

**Substituição recomendada:**
```
Para uso em Login ou contexto geral:

```
Seus laudos são privados. Revise antes de assinar.
```

Para uso em Generate, ReportDetail ou qualquer contexto com geração por IA:

```
IA gera minuta. Revise integralmente antes de assinar.
```
```

## MEDICAL_DISCLAIMER.md — Issue P2 #9

**Localização:** Seção 4, tabela “Quando exibir cada versão”.

**Problema:** `terms_accepted_at` mistura aceite de Termos, Privacidade e Disclaimer. Para defensibilidade, registre versão do documento aceito. O próprio documento já sugere isso tecnicamente, mas a tabela deveria refletir.

**Substituição recomendada:**
```
| Local | Versão | Frequência |
|---|---|---|
| **Modal de aceite inicial** (primeira vez que abre Generate logado) | Completa | 1× por Conta, registrando data/hora e versão aceita dos Termos, Política de Privacidade e Disclaimer Médico |
| **Configurações → "Sobre o LaudoUSG"** | Completa | Sempre disponível para consulta |
| **ReportDetail** (laudo gerado) | Resumida | Sempre, no rodapé, não-dispensável |
| **Generate (tela principal)** | Curta de IA | Sempre visível discretamente |
| **Login (footer)** | Curta geral | Sempre visível discretamente |
| **Onboarding (Sprint 11)** | Resumida | Tela 2 de 3 do onboarding |
```

## MEDICAL_DISCLAIMER.md — Issue P2 #10

**Localização:** Seção 5.1, Estado de aceite.

**Problema:** Só `terms_accepted_at` é pouco para prova. Precisa versões e talvez IP/user agent quando juridicamente necessário.

**Substituição recomendada:**
```
### 5.1 Estado de aceite

Tabela `public.profiles` já tem `terms_accepted_at: timestamp with time zone NULL`. Para melhor defensibilidade, recomenda-se registrar também:

- `terms_version_accepted`
- `privacy_version_accepted`
- `medical_disclaimer_version_accepted`
- `accepted_at`
- metadados técnicos mínimos do aceite, quando aplicável e proporcional

Quando o Usuário aceita o disclaimer + Termos + Privacy:

```typescript
UPDATE public.profiles
SET
  terms_accepted_at = NOW(),
  terms_version_accepted = $termsVersion,
  privacy_version_accepted = $privacyVersion,
  medical_disclaimer_version_accepted = $disclaimerVersion
WHERE id = $userId;
```
```

## MEDICAL_DISCLAIMER.md — Issue P2 #11

**Localização:** Seção 6.1, Pontos que merecem atenção do advogado.

**Problema:** Mantém referência à CFM 2.272/2020. Como você já está removendo, substitua por placeholder neutro.

**Substituição recomendada:**
```
- **Norma vigente do CFM sobre IA em medicina:** confirmar com advogado especializado qual norma está vigente na data de submissão e quais deveres específicos devem constar no app, no disclaimer e no fluxo de aceite.
```

## MEDICAL_DISCLAIMER.md — Cláusulas FALTANDO que recomendo adicionar

## MEDICAL_DISCLAIMER.md — Cláusula nova recomendada #1

**Localização:** Inserir após Seção 1.2 ou dentro dela.

**Problema:** Falta dever de informação ao paciente e registro de IA, com placeholder até confirmação humana da norma exata.

**Substituição recomendada:**
```
#### 1.2-A Informação ao paciente e registro profissional

Quando exigido pela legislação, norma do CFM, regra institucional ou boa prática aplicável ao caso, o médico Usuário deve informar o paciente ou responsável legal sobre o uso de IA como apoio relevante na elaboração do laudo e registrar esse uso no prontuário ou sistema equivalente.

O LaudoUSG não realiza essa comunicação automaticamente e não substitui o dever do médico de obter autorizações, registrar informações clínicas e cumprir obrigações éticas e documentais.
```

## MEDICAL_DISCLAIMER.md — Cláusula nova recomendada #2

**Localização:** Inserir após Seção 1.6.

**Problema:** Falta trilha de prova do aceite.

**Substituição recomendada:**
```
#### 1.7 Registro de aceite

O aceite deste Disclaimer poderá ser registrado com data, hora, versão do documento e identificador da Conta, para fins de segurança, auditoria, cumprimento legal e exercício regular de direitos. O uso continuado de funcionalidades de geração de laudo poderá ser condicionado ao aceite da versão vigente do Disclaimer, dos Termos de Uso e da Política de Privacidade.
```

## CONFIRMAÇÃO/CRÍTICA DAS 3 MUDANÇAS QUE VOCÊ JÁ ESTÁ APLICANDO

## P0.1 — Remoção CFM 2.272/2020 e placeholder de IA

Confirmo. Remover CFM 2.272/2020 é obrigatório. Usar placeholder “[norma vigente sobre IA em medicina, a confirmar com advogado]” é conservador e aceitável para draft interno, mas não deve ir para produção/App Store. Antes do submit, o placeholder precisa virar norma confirmada ou redação genérica sem placeholder visível.

Redação produtiva segura, se ainda não quiser citar número:
```
Normas vigentes do Conselho Federal de Medicina aplicáveis ao uso de tecnologias digitais e inteligência artificial na medicina, conforme revisão jurídica e médica especializada.
```

## P0.2 — Narrativa de minimização por design + tratamento incidental proibido + responsabilidade do Usuário como controlador

Confirmo a direção. Só cuidado para não dizer que o LaudoUSG nunca será operador. Se processa conteúdo por conta do médico, a posição mais defensável é:
```
O Usuário médico é controlador primário dos dados de seus pacientes. O LaudoUSG não exige dados identificáveis de pacientes e proíbe sua inserção. Caso o Usuário insira tais dados contra as regras do Serviço, o tratamento poderá ocorrer de forma incidental e limitada à prestação técnica do Serviço solicitado, hipótese em que o LaudoUSG poderá atuar como operador ou agente de tratamento conforme o caso concreto, sem assumir a finalidade clínica determinada pelo Usuário.
```

## P0.3 — Limitação de responsabilidade com ressalvas e teto R$ 500

Confirmo a direção, mas R$ 500 ainda pode ser atacado se houver dano relevante, defeito do serviço, relação de consumo, LGPD, culpa grave ou serviço pago com mensalidade superior. Mais importante que o valor é a ressalva. Redação melhor:
```
Na máxima extensão permitida pela legislação aplicável, e sem limitar direitos que não possam ser afastados por contrato, a responsabilidade da Controladora por danos diretos comprovadamente atribuíveis a defeito próprio do Serviço ficará limitada ao maior entre: (i) o valor efetivamente pago pelo Usuário à Controladora nos 12 (doze) meses anteriores ao fato gerador; ou (ii) R$ 500,00 (quinhentos reais). Este limite não se aplica a hipóteses de dolo, culpa grave, violação de direitos de titulares de dados pessoais, descumprimento de obrigação legal ou regulatória, defeito do serviço não limitável por lei, ou outras hipóteses em que a limitação seja vedada pela legislação aplicável.
```

## RECOMENDAÇÃO FINAL

Pode submeter na App Store assim como está? Não. Pode submeter depois de aplicar os P0s e, no mínimo, os P1s de Privacidade/Disclaimer. Os P2s podem ficar para refinamento, exceto versionamento de aceite, que eu trataria como quase P1 por valor probatório.

As 3 mudanças mais importantes depois dos P0s:

1. Ajustar Sala do Auxiliar, dever de sigilo do auxiliar e responsabilidade do médico pelo acesso delegado.
2. Inserir cláusula de não uso em urgência/emergência/sem revisão integral e trocar “proposta editorial” por “minuta automatizada de laudo”.
3. Corrigir Privacy Policy para base legal de conteúdo clínico sensível/incidental, operadores, transferência internacional e App Store labels.

O que ainda precisa de advogado humano:

1. Confirmar norma CFM vigente sobre IA em medicina e se deve ser citada nominalmente antes do submit.
2. Validar se o LaudoUSG pode ser tratado apenas como ferramenta de apoio à redação ou se alguma funcionalidade futura aproxima de software médico/SaMD.
3. Revisar DPAs/termos reais de Supabase, Vercel, OpenAI, Groq e Resend.
4. Conferir Privacy Nutrition Labels do App Store Connect contra tráfego real do app.
5. Revisar a estratégia de pessoa física vs pessoa jurídica antes de escalar billing e operação comercial.
