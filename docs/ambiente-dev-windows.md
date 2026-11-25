# Ambiente de desenvolvimento (Windows 11)

Os comandos rodam no PowerShell.

## Ferramentas

| Ferramenta | Uso | Observação |
|---|---|---|
| Git for Windows | Controle de versão | `git config --global core.longpaths true` |
| GitHub CLI (`gh`) | Repositório, releases e secrets | `winget install GitHub.cli`, depois `gh auth login` |
| Android Studio | App, SDK e emulador | Já vem com o JDK que o Gradle do Android usa |
| JDK 25 (Temurin) | Backend Quarkus | Instalação separada do JDK do Android |
| IntelliJ IDEA | Backend | — |
| Docker Desktop | Postgres e Dev Services do Quarkus | Usa o WSL2 por baixo; você não precisa trabalhar dentro do WSL |
| DBeaver | Inspecionar o banco | — |

## Cuidados no Windows

- **Pasta do projeto:** mantenha fora do OneDrive, porque a sincronização atrapalha o Gradle, e fora do sistema de arquivos do WSL.
- **Emulador:** com o Docker Desktop ligado, o Hyper-V fica ativo. Para o emulador funcionar junto, ative o recurso "Plataforma do Hipervisor do Windows".
- **Celular físico:** ative a depuração USB ou wireless e libere a porta da API no firewall do Windows, só para rede privada.
- **Endereço da API:**
  - No emulador, o PC é `10.0.2.2`.
  - No celular físico, use o IP do PC na rede.
  - HTTP sem TLS fica liberado só no build de debug, via `network_security_config`.
- **Finais de linha:** o `.gitattributes` força LF em tudo, exceto nos arquivos `*.bat`, `*.cmd` e `*.ps1`.

## Segredos

O repositório é público. A keystore, os arquivos `.env`, o `local.properties` e qualquer dado real do restaurante nunca entram no Git. No CI, a keystore e as senhas ficam nos secrets do GitHub Actions.

## Ordem de preparação

1. Criar o repositório e fazer o primeiro commit com os arquivos base.
2. Criar o projeto Android em `android/` pelo assistente do Android Studio (Empty Activity, Compose, Kotlin DSL).
3. Gerar o projeto Quarkus em `server/` pelo code.quarkus.io, com as extensões REST Jackson, Hibernate ORM Panache, JDBC Postgres, Flyway, SmallRye JWT e SmallRye Health.
4. Subir o Postgres com o docker compose e confirmar que `/q/health` responde.
5. Criar os workflows de CI.
