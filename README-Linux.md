# ZeroGate - Linux

Guia específico para compilar, testar e executar a versão Linux. Para funcionalidades comuns, configuração do token e arquitetura geral, consulte o [README principal](README.md).

No Linux, o app usa login local apenas por senha. A validação por biometria é ignorada nessa plataforma.

## Build e Testes via Docker

Os arquivos Docker da versão Linux ficam em `Docker/Linux` para não alterar a imagem usada pelo fluxo Android.

### Análise Estática

```bash
docker compose -f Docker/Linux/docker-compose.yml run --rm analyze
```

### Testes

```bash
docker compose -f Docker/Linux/docker-compose.yml run --rm test
```

### Build Linux

```bash
docker compose -f Docker/Linux/docker-compose.yml run --rm build
```

O executável será gerado em:

```text
build/linux/x64/release/bundle/zerogate
```

Para executar depois do build:

```bash
./build/linux/x64/release/bundle/zerogate
```

## Detalhes da Plataforma

- Plataforma alvo: Linux desktop x64.
- Artefato gerado: bundle nativo com binario ELF.
- Docker dedicado: `Docker/Linux/Dockerfile`.
- Compose dedicado: `Docker/Linux/docker-compose.yml`.
- Ícone e nome da janela são aplicados pelo runner GTK em `linux/runner/my_application.cc`.
- Plugins Linux usados pelo projeto incluem `shared_preferences_linux`, `flutter_secure_storage_linux` e `url_launcher_linux`.
- O armazenamento seguro usa `libsecret`; por isso o pacote `libsecret-1-0` é necessário em runtime e `libsecret-1-dev` em build.
- Cada [release](https://github.com/junglivre/ZeroGate/releases) publica o Linux em três formatos: `.tar.gz` (bundle genérico, extrair e rodar), `.deb` (instala em `/opt/zerogate` via `dpkg -i`) e `.rpm` (via `rpm -i` ou `dnf install`).

## Sessão

Ao fechar e reabrir o aplicativo, o login é exigido novamente. A sessão autenticada não fica persistida em disco.

## Referencias

- [README principal](README.md)
- [README Android](README-Android.md)
- [README Windows](README-Windows.md)
