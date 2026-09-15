# LaudoUSG - Privacy Nutrition Labels

Revisado em 13/09/2026 para o build 190. Este mapa substitui a orientacao antiga
que excluia imagens, dados clinicos e historico de compras. O questionario da
loja ainda precisa ser atualizado e relido apos a publicacao.

## Declaracoes

O app coleta dados. Para os tipos abaixo: App Functionality, vinculados a conta
e sem tracking publicitario. Vinculo com a conta do medico nao significa que
os dados clinicos sejam sobre o proprio medico.

| Tipo Apple | Uso confirmado |
| --- | --- |
| Name | Nome do medico e nomes informados nos laudos |
| Email Address | Autenticacao e comunicacao transacional |
| Health | Achados, medidas e laudos clinicos armazenados no historico |
| Sensitive Info | Informacoes obstetricas de gestacao/parto nos laudos |
| Photos or Videos | Imagens selecionadas para extracao de medidas; politica conservadora considerando processamento por terceiros |
| Audio Data | Ditado enviado a Deepgram/OpenAI para transcricao |
| Other User Content | Texto, frases e conteudo personalizado |
| User ID | Conta autenticada e vinculacao da compra Apple |
| Purchase History | Produtos, transacoes, vigencia e estado da assinatura Apple |
| Other Data Types | CRM, UF e preferencias profissionais |

Fotos nao significa acesso indiscriminado a fototeca nem coleta de videos:
o tipo agregado Apple cobre as imagens escolhidas pelo medico.
Health nao depende de integrar HealthKit: a definicao inclui outros dados
medicos fornecidos pelo usuario. Sensitive Info inclui gestacao/parto.

## Nao declarar sem evidencia de coleta

Nao ha formulario nativo de cartao/conta bancaria: Apple processa o pagamento.
Purchase History deve ser declarado, mas Payment Info nao e equivalente.
Perfil nativo coleta nome, email, CRM e UF, nao telefone ou endereco postal.
Other User Contact Info estava marcado na loja; revisar sua remocao porque
CRM/UF ja estao cobertos por Other Data Types, nao contato adicional.

Nao adicionar localizacao, contatos, fitness, ID publicitario, publicidade,
historico de navegacao ou de busca sem uma implementacao que os colete.
O painel de contagens de laudos nao demonstra por si so um SDK de analytics.
Rever este mapa se telemetria, suporte in-app ou novos provedores forem incluidos.

## Limites de evidencia

Nao prometer descarte imediato nos servidores de terceiros sem validar os
contratos/configuracoes reais. A ausencia de armazenamento proprio de audio
ou imagem nao demonstra ausencia de retencao pelo provedor.
O manifesto e o questionario devem refletir o app atual, sem dispensar a
politica publica nem a permissao IA separada.

## Fontes

- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest
- LaudoUSG/PrivacyInfo.xcprivacy
- LaudoUSG/Services/ProfileService.swift
- LaudoUSG/Services/ImageAnalysisService.swift
- LaudoUSG/Services/StoreManager.swift
- LaudoUSG/Resources/Legal/privacy-policy.md
