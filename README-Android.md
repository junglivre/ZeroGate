# ZeroGate - Android

Guia específico para testar e gerar os artefatos Android. Para funcionalidades comuns, configuração do token e arquitetura geral, consulte o [README principal](README.md).

No Android, o app suporta login por senha e biometria quando o dispositivo e o sistema operacional oferecem suporte.

## Desenvolvimento e Build via Docker

O fluxo Android usa os arquivos dedicados em `Docker/Android`.

### Teste em Modo Desenvolvimento

Para testar a interface sem emulador Android, o projeto usa o `web-server` do Flutter dentro do Docker:

```bash
docker compose -f Docker/Android/docker-compose.yml up test
```

Acesse:

```text
http://localhost:8080
```

O serviço `proxy` em `http://localhost:8081` existe para encaminhar chamadas da API Cloudflare durante o teste web.

### Build do APK e AAB

```bash
docker compose -f Docker/Android/docker-compose.yml run --rm build
```

O APK release será gerado em:

```text
build/app/outputs/flutter-apk/
```

Para gerar o Android App Bundle enviado à Google Play:

```bash
flutter build appbundle --release
```

O AAB será gerado em:

```text
build/app/outputs/bundle/release/app-release.aab
```

## JDK para build local

O toolchain Android do projeto (AGP 8.11, Kotlin 2.2.20) exige JDK 17 ou 21 no Gradle; com JDK 25 o build falha com `IllegalArgumentException: 25.0.2` vindo do compilador Kotlin. O CI usa Java 17. Para um build local sem trocar o Java padrão da máquina:

```bash
JAVA_HOME=~/.sdkman/candidates/java/17.0.20-tem flutter build apk --release
```

Ou fixe `org.gradle.java.home` em `~/.gradle/gradle.properties`.

## Assinatura dos artefatos

Os builds Android release exigem `android/key.properties` com as credenciais da keystore persistente. Sem esse arquivo, o Gradle interrompe o build.

Arquivos de keystore e `android/key.properties` devem permanecer fora do Git. Use sempre a mesma keystore persistente para assinar os AABs enviados à Google Play.

## Detalhes da Plataforma

- Plataforma alvo: Android.
- Artefatos gerados: APK e AAB.
- Docker dedicado: `Docker/Android/Dockerfile`.
- Compose dedicado: `Docker/Android/docker-compose.yml`.
- Pacote: `moe.jung.zerogate`.
- Permissões Android: internet e biometria.
- Ícone do launcher: `assets/icon.png`, gerado para `android/app/src/main/res/mipmap-*`.
- Biometria: implementada com `local_auth`.
- Segredos locais: `flutter_secure_storage`.

## Sessão

Ao fechar e reabrir o aplicativo, o login é exigido novamente. A sessão autenticada não fica persistida em disco.

## Referencias

- [README principal](README.md)
- [README Linux](README-Linux.md)
- [README Windows](README-Windows.md)
