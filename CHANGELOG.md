# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2] - 2026-10-02
### Added
- Tunnel list now shows each tunnel's uptime next to its status and connector count (hidden while the tunnel is offline).
- Tunnel detail screen now lists the tunnel's private-network routes (CIDR routing for WARP, read-only), flagging any route whose CIDR is also routed by a different tunnel as "shared".
- Linux releases now also publish `.deb` and `.rpm` packages (installing to `/opt/zerogate`), alongside the existing `.tar.gz` bundle.

## [1.0.1] - 2026-08-25
### Added
- A concise token-creation guide is shown when no Cloudflare API token is configured.

### Security
- Revealing the stored API token now requires the app password or platform biometric authentication.

## [1.0.0] - 2026-07-28
### First release
- Local password authentication, with biometric login on platforms that support it.
- Selecting and switching between the Cloudflare accounts visible to the configured token.
- Cloudflare Tunnel listing with status and active connectors.
- Route editor (Public Hostname) with a destination type selector (http, https, tcp, ssh, rdp, smb, unix, unix+tls) and advanced HTTP/HTTPS settings.
- Listing, creating, editing, and deleting Access Apps, with a policy editor (email, email domain, everyone, IP).
- Portuguese, English, and Spanish UI; light, dark, or automatic theme.
- In-app version history (changelog) view.
- Automated builds via GitHub Actions for Android, Linux, macOS, and Windows, with releases triggered by pushing a version tag (`X.Y.Z`, no leading `v`).
