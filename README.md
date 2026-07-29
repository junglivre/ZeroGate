<img src="assets/icon.png" alt="ZeroGate" width="80">

English | [Português](README.br.md) | [Español](README.es.md)

# ZeroGate

[![CI](https://github.com/junglivre/ZeroGate/actions/workflows/ci.yml/badge.svg)](https://github.com/junglivre/ZeroGate/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white) ![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Web-informational)

A Flutter application for managing Cloudflare Zero Trust from your phone or desktop: tunnels (Cloudflare Tunnel), their routes (Public Hostname) and Access Apps with their policies — no need to open the dashboard.

> Sibling project of [Cloudflare DNS Manager](https://github.com/Tacioandrade/cloudflare-dns-manager), reusing the same local-auth foundation and Flutter architecture.

This README contains information shared by all platforms. For build commands, tests, and platform-specific details, see [Android](README-Android.md), [Linux](README-Linux.md), [Windows](README-Windows.md), [iOS](README-iOS.md), and [macOS](README-macOS.md).

## Features

- Local password authentication, with biometric login on platforms that support it.
- Automatic logout when the application is closed and reopened.
- Selecting/switching between the Cloudflare accounts the token can see.
- Cloudflare Tunnel list with status (healthy, degraded, down) and active connectors.
- Route editor (Public Hostname / ingress rules) for each tunnel: create, edit, and delete hostname → local service mappings, with a destination type selector (http, https, tcp, ssh, rdp, smb, unix, unix+tls) and advanced HTTP/HTTPS settings (origin TLS/SSL verification, SNI, Host header, HTTP/2, timeouts, keep-alive, proxying).
- Access App list (self-hosted) with creation, editing of name/domain/session duration, and deletion.
- Per-app Access policy editor: action (Allow/Block/Bypass/Service Auth) and Include/Exclude/Require rules for the most common selectors (email, email domain, everyone, IP). Rules using selectors the editor doesn't support are preserved unchanged.
- Light, dark, or system theme.
- Portuguese and English UI.
- In-app changelog view.

## Access and security

On first use, the application opens the password-creation screen. Every subsequent launch requires logging in again.

The authenticated session exists only in memory. The application password is not stored as plain text — only a PBKDF2-HMAC-SHA256 hash with a random salt is kept in the platform's secure storage. The Cloudflare token is also stored securely. Theme, language, and the selected account remain saved locally in regular preferences.

## Cloudflare API token

1. Sign in to the application.
2. Open **Settings**.
3. Paste your [Cloudflare API Token](https://dash.cloudflare.com/profile/api-tokens).
4. Select **Test**, then **Save**.

Create a custom token with these permissions:

| Scope | Permission | Level |
|---|---|---|
| Account | `Cloudflare Tunnel` | Read, Edit |
| Account | `Access: Apps and Policies` | Read, Edit |
| Account | `Account Settings` | Read |
| User | `Memberships` | Read |

The first two grant access to tunnels/routes and Access Apps. The last two (`Account Settings` and `Memberships`) are what makes the account(s) show up on the app's account picker — without them, the connection test passes but the account list comes back empty.

When creating the token, under **Account Resources** select every account you want to manage from this app — the app lists those accounts and lets you switch between them. This avoids using the Global API Key (unrestricted access to the whole Cloudflare account) in favor of an explicitly scoped token.

## Architecture

- Framework: Flutter / Dart
- Non-sensitive local state: `shared_preferences`
- Local secrets: `flutter_secure_storage`
- Biometric authentication: `local_auth`, where supported by the platform
- Network communication: `http`, directly to `api.cloudflare.com/client/v4`
- Opening external links: `url_launcher`

## Automated builds (GitHub Actions)

- **CI** (`.github/workflows/ci.yml`): runs on every push/PR to `main`. Runs `flutter analyze` + `flutter test` and, if that passes, builds Android (debug, split per ABI), Linux, macOS, and Windows, publishing each as a workflow *artifact* (repo's **Actions** tab) — handy for grabbing and testing any commit without waiting for a release.
- **Release** (`.github/workflows/release.yml`): triggered by pushing a version tag (e.g. `git tag 1.0.0 && git push origin 1.0.0` — no leading `v`, same convention as the author's other projects). Creates the [GitHub Release](https://github.com/junglivre/ZeroGate/releases) using the matching `CHANGELOG.md` section as the notes, then builds all four platforms in release mode and attaches the files to it.
- **Android signing**: release APKs are signed with a persistent upload keystore, decoded at build time from the `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` repo secrets — never committed to the repo. It's the same upload key used across the author's other apps (that's how Play App Signing is meant to work: the upload key only authenticates uploads, Google manages the actual app signing key per app). Because the key is persistent, APKs from consecutive releases install over each other as an update.

## Scope and known limitations

- Managed routes are the tunnel's ingress/Public Hostname rules (what shows up under the "Public Hostname" tab in the dashboard). The app does not manage private-network CIDR/hostname routing (`teamnet/routes`, used by WARP/Cloudflare Mesh).
- Tunnel connectors are read-only — they are managed by the `cloudflared` daemon, not by this app.
- The Access policy editor covers the most common selectors (email, email domain, everyone, IP). More advanced selectors (IdP groups, device posture, geolocation, service tokens) still require the Cloudflare dashboard; the app preserves those rules instead of discarding them.

## Guide structure

- `README-Android.md`: Build documentation and version details for Android.
- `README-Linux.md`: Build documentation and version details for Linux.
- `README-Windows.md`: Build documentation and version details for Windows.
- `README-iOS.md`: Build documentation and version details for iOS.
- `README-macOS.md`: Build documentation and version details for macOS.

## Known issue

Windows requires Microsoft Visual C++ Redistributable 2015–2022. Install it from [Microsoft's official download page](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) if `MSVCP140.dll`, `VCRUNTIME140.dll`, or `VCRUNTIME140_1.dll` is missing.

## License

MIT
