# AGENTS.md

## Nome do Projeto

- O nome do projeto/aplicativo e **ZeroGate**.
- Use **ZeroGate** para qualquer texto visivel ao usuario, documentacao, titulos de janela, atalhos, nomes de instalador, nomes de menu, nomes de pacote distribuivel e metadados publicos.

## Contexto do Projeto

- Este e um aplicativo Flutter/Dart para gerenciar Cloudflare Zero Trust: tuneis Cloudflare Tunnel (`cfd_tunnel`), suas rotas/Public Hostname (ingress rules) e Cloudflare Access Applications com suas politicas.
- E um projeto irmao do `cloudflare-dns-manager` (app de DNS da mesma familia), reaproveitando os mesmos padroes de autenticacao local, armazenamento seguro, tema e idioma.
- O pacote Dart atual e `zerogate` (nome em `pubspec.yaml`).
- Identificador do app (applicationId Android / namespace / bundle ID iOS-macOS / APPLICATION_ID Linux): `moe.jung.zerogate`.
- O app armazena configuracoes nao sensiveis (tema, idioma, conta selecionada) com `shared_preferences`.
- Segredos locais, como senha do app e token da Cloudflare, usam `flutter_secure_storage`.
- A senha local do app nao deve ser salva em texto claro; o app usa hash PBKDF2-HMAC-SHA256 com salt aleatorio.
- Autenticacao biometrica usa `local_auth` quando a plataforma suporta.
- Comunicacao de rede usa `http`, direto para `api.cloudflare.com/client/v4`.
- Links externos usam `url_launcher`.

## Modelo de Conta

- O app usa um unico API Token Cloudflare (nao Global API Key), guardado em `flutter_secure_storage`.
- O token pode ser escopado para multiplas contas na Cloudflare (selecionavel na criacao do token). O app lista essas contas via `GET /accounts` e deixa o usuario escolher/trocar a conta ativa (`AccountsScreen`).
- Toda chamada de Tunnels/Access e feita com o `account_id` da conta ativa, guardado em `shared_preferences`.
- Permissoes minimas recomendadas para o token (validadas manualmente contra a API real):
  - Account: `Cloudflare Tunnel: Read, Edit`
  - Account: `Access: Apps and Policies: Read, Edit`
  - Account: `Account Settings: Read` — sem essa, `GET /accounts` responde `success: true` com lista vazia (o teste de token passa, mas nenhuma conta aparece no app).
  - User: `Memberships: Read` — necessaria para o token enxergar as contas das quais o usuario e membro.
  - Em Account Resources, incluir todas as contas desejadas (ou "All accounts").

## Escopo de "rotas"

- O app gerencia as regras de ingress (Public Hostname) de cada Cloudflare Tunnel via `GET`/`PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations`.
- Ele **nao** gerencia o roteamento de rede privada por CIDR/hostname (`teamnet/routes`, usado por WARP/Cloudflare Mesh) — e um conceito diferente, fora do escopo atual.
- Conectores/conexoes do tunel (`.../connections`) sao somente leitura: sao geridos pelo daemon `cloudflared`, nao por este app.
- O editor de rota (`route_editor_screen.dart`) separa o destino em tipo (dropdown com os schemes documentados: `http`, `https`, `tcp`, `ssh`, `rdp`, `smb`, `unix`, `unix+tls`) e endereço, reconstruindo o `service` (`scheme://endereco` ou `scheme:endereco` para unix/unix+tls) via `IngressRuleValidator.buildService`/`parseService`.
- Para destinos `http`/`https`, expõe as opções de `originRequest` documentadas na API do Cloudflare Tunnel (`noTLSVerify`, `originServerName`, `matchSNItoHost`, `httpHostHeader`, `http2Origin`, `disableChunkedEncoding`, `noHappyEyeballs`, `proxyType`, `caPool`, `connectTimeout`, `tlsTimeout`, `tcpKeepAlive`, `keepAliveConnections`, `keepAliveTimeout`). Qualquer chave de `originRequest` que o editor não conhece (ex.: `access`, usado para validar JWT do Access na própria origem) é preservada sem alteração ao salvar — ver `_kKnownOriginRequestKeys`/`_passthroughOriginRequest` em `route_editor_screen.dart`, mesmo padrão de passthrough usado no editor de políticas de Access.

## Politicas de Access

- O editor de politicas (`AccessPolicyEditorScreen`) cobre os seletores mais comuns: `email`, `email_domain`, `everyone` e `ip`.
- Qualquer regra com outro seletor (grupo de IdP, postura de dispositivo, geo, service token, etc.) e preservada sem alteracao ao salvar — nunca deve ser descartada silenciosamente. Ver `_isKnownRule`/`_passthrough` em `access_policy_editor_screen.dart`.

## Plataformas

- Plataformas com suporte/documentacao no projeto: Android, iOS, Linux, macOS e Windows.
- Existe uma pasta Flutter tambem para Web; trate alteracoes nela com cuidado e teste quando for afetada.
- Leia os guias especificos antes de mudar comandos, nomes ou empacotamento:
  - `README-Android.md`
  - `README-iOS.md`
  - `README-Linux.md`
  - `README-macOS.md`
  - `README-Windows.md`

## Comandos Uteis

- Validacao estatica: `flutter analyze`
- Testes: `flutter test`
- Build Android: consulte `README-Android.md`
- Build iOS: consulte `README-iOS.md`
- Build Linux: consulte `README-Linux.md`
- Build macOS: consulte `README-macOS.md`
- Build Windows: consulte `README-Windows.md`

## CI/CD (GitHub Actions)

- `.github/workflows/ci.yml`: push/PR em `main` → `flutter analyze` + `flutter test`, depois builda Android (debug, split-per-abi)/Linux/macOS/Windows e publica cada um como artifact do workflow (nao publica release).
- `.github/workflows/release.yml`: dispara em `push: tags: "[0-9]+.[0-9]+.[0-9]+"` (sem `v` na frente, mesma convencao do TypeBridge). Job `create_release` extrai a secao correspondente do `CHANGELOG.md` e roda `gh release create`; os jobs de build (`needs: create_release`) buildam as 4 plataformas e sobem os arquivos via `gh release upload`. Tudo num workflow so — sem hack de `workflow_dispatch`. Para cortar uma release: bump de versao em `pubspec.yaml` + entrada no `CHANGELOG.md`, commit (pode terminar em "(X.Y.Z)" como convencao/lembrete, isso nao aciona nada sozinho), depois `git tag X.Y.Z && git push origin X.Y.Z` — precisa ser um push com credencial real do usuario, nao GITHUB_TOKEN (GitHub suprime eventos de push criados pelo GITHUB_TOKEN pra evitar loop infinito, entao uma tag empurrada por um bot nunca dispararia o workflow).
- Android release usa uma keystore de upload **persistente**, decodificada em tempo de build a partir dos secrets `ANDROID_KEYSTORE_BASE64`/`ANDROID_KEYSTORE_PASSWORD`/`ANDROID_KEY_ALIAS`/`ANDROID_KEY_PASSWORD` (step "Decode release signing key" em `release.yml`) — nunca commitada no repo. É a mesma chave de upload reaproveitada nos outros apps do autor (jung), local em `~/.keystores/jung-upload/`. Por ser persistente, APKs de releases consecutivas instalam um por cima do outro como atualizacao. **Nao gerar nem substituir a keystore de producao, nem os secrets do repo, sem confirmar explicitamente com o usuario antes** — essa decisao é dele.
- `ci.yml` (debug/CI) continua usando uma keystore descartavel gerada dentro do proprio job (nunca salva como secret ou artifact), so pra satisfazer o throw de `android/app/build.gradle.kts` — nao ha necessidade de assinatura persistente para os artifacts de debug de cada commit.
- Versoes do Flutter/Java pinadas nos workflows (`FLUTTER_VERSION` env + `java-version: '17'`) devem ficar alinhadas com o que funciona localmente (ver `android/gradle/wrapper/gradle-wrapper.properties` e `android/settings.gradle.kts` para as versoes de Gradle/AGP/Kotlin correspondentes).

## Cuidados de Manutencao

- Antes de renomear packages, application IDs, bundle IDs ou namespaces, verifique impacto em atualizacoes, assinatura, armazenamento local e compatibilidade com instalacoes existentes.
- Quando alterar textos ou nomes de aplicativo, verifique Linux, Windows, Android, Web manifest e configuracoes de macOS/iOS se forem relevantes.
- Mantenha o `CHANGELOG.md` atualizado para mudancas de usuario, releases e ajustes de empacotamento.
- Preserve o estilo atual do projeto: Flutter simples, dependencias enxutas e configuracoes por plataforma documentadas nos READMEs.
