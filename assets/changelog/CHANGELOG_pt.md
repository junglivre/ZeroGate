# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

## [1.1.0] - 2026-11-14
### Corrigido
- Rotas criadas sem DNS agora sincronizam seus registros CNAME proxied.
- Salvar rotas não sobrescreve mais o restante da configuração do túnel.
- Editar uma rota não perde mais seu `path`.

### Alterado
- Os tokens da API Cloudflare agora exigem `Zone: Read` e `DNS: Edit`, com o escopo adequado em Zone Resources.
- Os hostnames das rotas são canonizados em minúsculas, sem espaços ao redor ou ponto final.
- As releases Windows agora trazem um instalador NSIS (`-setup.exe`) além do `.zip` portátil; ambos incluem o runtime do Visual C++.

## [1.0.2] - 2026-10-02
### Adicionado
- A lista de túneis agora mostra o tempo de atividade de cada túnel ao lado do status e da quantidade de conectores (oculto enquanto o túnel está inativo).
- A tela de detalhes do túnel agora lista as rotas de rede privada (roteamento CIDR para WARP, somente leitura), marcando como "compartilhada" qualquer rota cujo CIDR também seja roteado por outro túnel.
- As releases Linux agora também publicam pacotes `.deb` e `.rpm` (instalados em `/opt/zerogate`), além do bundle `.tar.gz` existente.

## [1.0.1] - 2026-08-25
### Adicionado
- Um guia conciso de criação do token é exibido quando nenhum token da API Cloudflare está configurado.

### Segurança
- Revelar o token da API armazenado agora exige a senha do app ou autenticação biométrica da plataforma.

## [1.0.0] - 2026-07-28
### Primeira versão
- Autenticação local por senha, com login biométrico nas plataformas que suportam.
- Seleção e troca entre as contas Cloudflare visíveis pelo token configurado.
- Listagem de túneis (Cloudflare Tunnel) com status e conectores ativos.
- Editor de rotas (Public Hostname) com seletor de tipo de destino (http, https, tcp, ssh, rdp, smb, unix, unix+tls) e configurações avançadas de HTTP/HTTPS.
- Listagem, criação, edição e exclusão de Access Apps, com editor de políticas (e-mail, domínio de e-mail, todos, IP).
- Interface em português e inglês; tema claro, escuro ou automático.
- Histórico de versões (changelog) renderizado dentro do próprio app.
- Build automático via GitHub Actions para Android, Linux, macOS e Windows, com release disparada ao empurrar uma tag de versão (`X.Y.Z`, sem `v` na frente).
