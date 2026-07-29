# ZeroGate - macOS

Guia para compilar e testar a versão macOS em um Mac. A compilação exige macOS, Xcode e CocoaPods.

## Preparação

1. Instale o Flutter, Xcode e CocoaPods.
2. Execute `flutter pub get` para instalar os pods.
3. Abra `macos/Runner.xcworkspace` no Xcode para configurar assinatura e distribuição.

## Testes e build

```bash
flutter pub get
flutter test
flutter build macos --release
```

O bundle é gerado em `build/macos/Build/Products/Release/`.

Uma tag de versão empurrada (`git tag 1.0.0 && git push origin 1.0.0`) dispara `.github/workflows/release.yml`, que builda e anexa esse bundle numa [GitHub Release](https://github.com/junglivre/ZeroGate/releases) criada automaticamente, assinado ad-hoc. Para distribuição pública fora da Release, gere o bundle localmente com o comando acima e assine/notarize conforme a seção abaixo.

## Detalhes

- Alvo mínimo: macOS 10.15.
- Bundle ID: `moe.jung.zerogate`.
- O sandbox inclui acesso de rede de saída para a API Cloudflare.
- O acesso ao Keychain está habilitado para armazenar o token e a senha com segurança.
- Para distribuição pública, configure a equipe Apple, certificado Developer ID e notarização no Xcode — sem isso, o bundle só roda localmente com assinatura ad-hoc.
