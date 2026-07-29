# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

## [1.0.0] - 2026-07-28
### Primeira versão
- Autenticação local por senha, com login biométrico nas plataformas que suportam.
- Seleção e troca entre as contas Cloudflare visíveis pelo token configurado.
- Listagem de túneis (Cloudflare Tunnel) com status e conectores ativos.
- Editor de rotas (Public Hostname) com seletor de tipo de destino (http, https, tcp, ssh, rdp, smb, unix, unix+tls) e configurações avançadas de HTTP/HTTPS.
- Listagem, criação, edição e exclusão de Access Apps, com editor de políticas (e-mail, domínio de e-mail, todos, IP).
- Interface em português, inglês e espanhol; tema claro, escuro ou automático.
- Histórico de versões (changelog) renderizado dentro do próprio app.
- Build automático via GitHub Actions para Android, Linux, macOS e Windows, com release disparada ao empurrar uma tag de versão (`X.Y.Z`, sem `v` na frente).
