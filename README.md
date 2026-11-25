# Estoque Pantanal

Controle de estoque de bebidas do restaurante Pantanal (Cascavel, PR).

O gerente cadastra fornecedores e produtos, com estoque mínimo e ideal. Os funcionários fazem a contagem pelo app Android, que funciona offline. O app gera o pedido sugerido para cada fornecedor e o envia pelo WhatsApp.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `android/` | App Android (Kotlin, Jetpack Compose, Room, WorkManager) |
| `server/` | API (Quarkus, Java 25, Postgres, Flyway) |
| `infra/` | Docker Compose e scripts de backup |
| `docs/` | Decisões, roadmap e ambiente de desenvolvimento |

## Rodando localmente

Pré-requisitos: Docker Desktop, JDK 25 e Android Studio.

1. Copie `infra/.env.example` para `infra/.env` e ajuste as senhas.
2. Suba o banco de dados:
   ```powershell
   docker compose -f infra/docker-compose.yml up -d
   ```
3. Rode a API em `server/` (`./mvnw quarkus:dev`) e confira se `http://localhost:8080/q/health` responde.
4. Abra `android/` no Android Studio e rode no emulador. No emulador, a API fica em `http://10.0.2.2:8080`.

## Segredos

Nunca versionar a keystore de assinatura, os arquivos `.env`, o `local.properties` ou dados reais do restaurante. No CI, eles ficam nos secrets do GitHub Actions.

## Documentação

- [Decisões e roadmap](docs/decisoes-e-roadmap.md)
- [Ambiente de desenvolvimento (Windows)](docs/ambiente-dev-windows.md)
