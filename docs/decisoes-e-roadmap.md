# Decisões e roadmap

## Contexto
Hoje o restaurante controla o estoque de bebidas à mão, numa lista de WhatsApp separada por fornecedor. O app substitui essa lista: o gerente cadastra fornecedores e produtos, e a equipe faz a contagem pelo celular. O sistema de caixa (PDV) atual continua como está.

## Viabilidade
- **Distribuição:** não usa a Play Store. O APK assinado fica no GitHub Releases, com uma conta de distribuição limitada no Android Developer Console (até 20 aparelhos, instalação por convite). Desde 30/09/2026, o Brasil exige desenvolvedor verificado mesmo para apps instalados por fora da loja.
- **Persistência:** os dados ficam num servidor com backup automático diário, guardado num meio diferente do servidor.
- **Offline:** o Wi-Fi falha no estoque, então o app é nativo e offline-first. As alterações entram numa fila e são enviadas quando a rede volta.
- **WhatsApp:** link `wa.me` com o texto do pedido já pronto, sem usar a API do WhatsApp.

## Decisões
- **App:** Kotlin, Jetpack Compose, Room (fonte da verdade da tela), WorkManager (envio da fila), Hilt e DataStore.
- **Backend:** Quarkus (Java 25), Postgres e Flyway, empacotados com Docker Compose. O destino preferido é um servidor local no restaurante, com backup externo.
- **Sincronização:**
  - O app gera os UUIDs, e o servidor descarta envios repetidos sem duplicar dados.
  - Endpoints: `POST /sync/push` e `GET /sync/pull?since=`.
  - Exclusões são marcadas com `deleted_at`.
  - Contagens só recebem registros novos; nada é sobrescrito.
- **Autenticação:**
  - Uma única tela de login; o papel do usuário (gerente ou funcionário) define as permissões.
  - Usa JWT. O primeiro acesso de cada aparelho precisa de rede.
- **Monorepo:** pastas `android/`, `server/`, `infra/`, `docs/` e `.github/workflows/`.

## Regras de estoque
- **Cadastro de cada produto:**
  - Estoque mínimo: o gatilho do alerta.
  - Estoque ideal: o alvo do pedido.
  - Embalagem e unidades por embalagem.
- **Contagem:** sempre em unidades.
- **Pedido sugerido:**
  - Quantidade: ideal − contado, arredondada para embalagens fechadas.
  - Os itens são agrupados por fornecedor.

## Modelo de dados (rascunho)
- **Fornecedor:** id, nome, whatsapp, obs, updated_at, deleted_at
- **Produto:** id, fornecedor_id, sku, nome, descricao, unidade, embalagem, fator, minimo, ideal, updated_at, deleted_at
- **Contagem:** id, fornecedor_id, usuario_id, data
- **ItemContagem:** id, contagem_id, produto_id, quantidade, observacao
- **Usuario:** id, login, hash_senha, nome, papel, ativo

## Roadmap
1. MVP de estoque, com contagem manual.
2. Baixa automática no estoque a partir das vendas registradas no caixa.
3. App do garçom.
4. Integrações adicionais com o caixa, se houver interface oficial do fornecedor para isso.
