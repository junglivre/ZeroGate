<img src="assets/icon.png" alt="ZeroGate" width="80">

[English](README.md) | Português | [Español](README.es.md)

# ZeroGate

[![CI](https://github.com/junglivre/ZeroGate/actions/workflows/ci.yml/badge.svg)](https://github.com/junglivre/ZeroGate/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white) ![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Web-informational)

Aplicativo em Flutter para gerenciar Cloudflare Zero Trust direto do celular ou desktop: túneis (Cloudflare Tunnel), suas rotas (Public Hostname) e Access Apps com suas políticas — sem precisar abrir o dashboard.

> Projeto irmão do [Cloudflare DNS Manager](https://github.com/Tacioandrade/cloudflare-dns-manager), reaproveitando a mesma base de autenticação local e arquitetura Flutter.

Este README contém as informações compartilhadas entre as plataformas. Para comandos de build, testes e detalhes específicos, use os guias por sistema operacional:

- [Android](README-Android.md)
- [Linux](README-Linux.md)
- [Windows](README-Windows.md)
- [iOS](README-iOS.md)
- [macOS](README-macOS.md)

## Funcionalidades

- Autenticação local por senha, com login por biometria nas plataformas que suportam essa integração.
- Logout automático ao fechar e reabrir o aplicativo, exigindo novo login.
- Seleção/troca entre as contas Cloudflare que o token enxerga.
- Lista de túneis Cloudflare Tunnel com status (saudável, degradado, inativo) e conectores ativos.
- Editor de rotas (Public Hostname / ingress rules) de cada túnel: criar, editar e excluir hostname → serviço local, com seletor de tipo de destino (http, https, tcp, ssh, rdp, smb, unix, unix+tls) e configurações avançadas de HTTP/HTTPS (TLS/SSL do destino, SNI, cabeçalho Host, HTTP/2, timeouts, keep-alive, proxy).
- Lista de Access Apps (self-hosted) com criação, edição de nome/domínio/duração de sessão e exclusão.
- Editor de políticas de Access por app: ação (Permitir/Bloquear/Bypass/Service Auth) e regras Incluir/Excluir/Exigir para os seletores mais comuns (e-mail, domínio de e-mail, todos, IP). Regras com seletores não suportados pelo editor são preservadas sem alteração.
- Tema claro, escuro ou automático pelo sistema.
- Interface em português e inglês.
- Visualização do changelog dentro do aplicativo.

## Acesso

No primeiro acesso, o aplicativo abre a tela de criação de senha. Depois disso, cada nova execução do app exige login novamente.

A sessão autenticada fica apenas em memória. A senha do app não é salva em texto claro; o app armazena apenas um hash PBKDF2-HMAC-SHA256 com salt aleatório no armazenamento seguro da plataforma. O token da Cloudflare também fica no armazenamento seguro. Tema, idioma e a conta selecionada continuam salvos localmente em preferências comuns.

## Cloudflare API Token

1. Faça login no aplicativo.
2. Abra Configurações.
3. Cole seu [Cloudflare API Token](https://dash.cloudflare.com/profile/api-tokens).
4. Clique em Testar para validar.
5. Clique em Salvar.

Crie um token customizado com as seguintes permissões:

| Escopo | Permissão | Nível |
|---|---|---|
| Account | `Cloudflare Tunnel` | Leitura, Edição |
| Account | `Access: Apps and Policies` | Leitura, Edição |
| Account | `Account Settings` | Leitura |
| User | `Memberships` | Leitura |

As duas primeiras dão acesso aos túneis/rotas e Access Apps. As duas últimas (`Account Settings` e `Memberships`) são o que faz a(s) conta(s) aparecerem na tela de seleção de conta do app — sem elas, o teste de conexão passa, mas a lista de contas vem vazia.

Ao criar o token, em **Account Resources** selecione todas as contas que deseja gerenciar por este app — o app lista essas contas e permite trocar entre elas. Isso evita usar a Global API Key (acesso irrestrito a toda a conta Cloudflare), preferindo um token com escopo explícito.

## Arquitetura

- Framework: Flutter / Dart
- Estado local não sensível: `shared_preferences`
- Segredos locais: `flutter_secure_storage`
- Autenticação biométrica: `local_auth`, quando suportado pela plataforma
- Comunicação de rede: `http`, direto para `api.cloudflare.com/client/v4`
- Abertura de links externos: `url_launcher`

## Build automático (GitHub Actions)

- **CI** (`.github/workflows/ci.yml`): roda em todo push/PR para `main`. Executa `flutter analyze` + `flutter test` e, se passar, builda Android (debug, split por ABI), Linux, macOS e Windows, disponibilizando cada um como *artifact* do workflow (aba **Actions** do repositório) — útil pra baixar e testar qualquer commit sem esperar uma release.
- **Release** (`.github/workflows/release.yml`): disparado ao empurrar uma tag de versão (ex.: `git tag 1.0.0 && git push origin 1.0.0` — sem `v` na frente, mesma convenção usada nos outros projetos do autor). Cria a [GitHub Release](https://github.com/junglivre/ZeroGate/releases) usando a seção equivalente do `CHANGELOG.md` como notas, depois builda as quatro plataformas em modo release e anexa os arquivos nela.
- **Assinatura do Android**: os APKs de release são assinados com uma keystore de upload persistente, decodificada em tempo de build a partir dos secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD` — nunca commitada no repositório. É a mesma chave de upload usada nos demais apps do autor (é assim que o Play App Signing funciona: a chave de upload só autentica o envio, o Google gerencia a chave de assinatura real de cada app). Como a chave é persistente, os APKs de releases consecutivas instalam um por cima do outro como atualização.

## Escopo e limitações conhecidas

- Rotas gerenciadas são as regras de ingress/Public Hostname do túnel (o que aparece na aba "Public Hostname" do dashboard). O app não gerencia roteamento de rede privada por CIDR/hostname (`teamnet/routes`, usado por WARP/Cloudflare Mesh).
- Conectores do túnel são somente leitura — são geridos pelo daemon `cloudflared`, não por este app.
- O editor de políticas de Access cobre os seletores mais comuns (e-mail, domínio de e-mail, todos, IP). Seletores mais avançados (grupos de IdP, postura de dispositivo, geolocalização, service tokens) precisam do painel Cloudflare; o app preserva essas regras sem descartá-las.

## Estrutura dos Guias

- `README-Android.md`: Documentação do build e detalhes da versão para Android.
- `README-Linux.md`: Documentação do build e detalhes da versão para Linux.
- `README-Windows.md`: Documentação do build e detalhes da versão para Windows.
- `README-iOS.md`: Documentação do build e detalhes da versão para iOS.
- `README-macOS.md`: Documentação do build e detalhes da versão para macOS.

## Problemas Conhecidos

- A versão para Windows exige o Microsoft Visual C++ Redistributable 2015-2022 instalado para executar. Sem esse runtime, o Windows pode exibir erro informando a falta das DLLs `MSVCP140.dll`, `VCRUNTIME140.dll` ou `VCRUNTIME140_1.dll`. Instale pelo site oficial da Microsoft: [Latest supported Visual C++ Redistributable downloads](https://learn.microsoft.com/pt-br/cpp/windows/latest-supported-vc-redist).

## Licença

MIT
