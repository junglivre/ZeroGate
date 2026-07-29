# ZeroGate - Windows

Guia específico para compilar, testar e executar a versão Windows. Para funcionalidades comuns, configuração do token e arquitetura geral, consulte o [README principal](README.md).

No Windows, o app suporta login por senha e biometria via Windows Hello quando o dispositivo e o sistema operacional oferecem suporte.

## Build e Testes via Docker

Os arquivos Docker da versão Windows ficam em `Docker/Windows` para não alterar os fluxos Android e Linux.

Este fluxo usa Windows containers. Execute em uma máquina Windows com Docker Desktop alternado para Windows containers. Ele não roda em Linux containers nem em Docker Engine Linux/WSL.

### Análise Estática

```powershell
docker compose -f Docker/Windows/docker-compose.yml run --rm analyze
```

### Testes

```powershell
docker compose -f Docker/Windows/docker-compose.yml run --rm test
```

### Build Windows

```powershell
docker compose -f Docker/Windows/docker-compose.yml run --rm build
```

O bundle release será gerado em:

```text
build\windows\x64\runner\Release\
```

O executável principal será:

```text
build\windows\x64\runner\Release\zerogate.exe
```

## Detalhes da Plataforma

- Plataforma alvo: Windows desktop x64.
- Artefato gerado: bundle nativo com `.exe`.
- Docker dedicado: `Docker/Windows/Dockerfile`.
- Compose dedicado: `Docker/Windows/docker-compose.yml`.
- Runner nativo: `windows/runner/`.
- Ícone do executável: `windows/runner/resources/app_icon.ico`.
- Biometria: `local_auth_windows`, usando Windows Hello quando disponível.
- Segredos locais: `flutter_secure_storage_windows`.

## Toolchain no Container

A imagem Windows instala:

- Flutter `3.22.0`.
- Git for Windows.
- Visual Studio Build Tools com C++ workload, CMake e Windows SDK.

A primeira compilação pode demorar bastante porque a imagem baixa e instala o toolchain nativo Windows.

## Sessão

Ao fechar e reabrir o aplicativo, o login é exigido novamente. A sessão autenticada não fica persistida em disco.

## Referencias

- [README principal](README.md)
- [README Android](README-Android.md)
- [README Linux](README-Linux.md)
