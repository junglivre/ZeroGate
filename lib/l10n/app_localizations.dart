import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  static const supportedLocales = [
    Locale('pt'), Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key, {Map<String, String> values = const {}}) {
    var value = (_translations[locale.languageCode] ?? _translations['en']!)[key] ??
        _translations['en']![key] ?? key;
    values.forEach((name, replacement) => value = value.replaceAll('{$name}', replacement));
    return value;
  }

  static const _translations = <String, Map<String, String>>{
    'en': {
      'appName': 'ZeroGate',
      'settings': 'Settings', 'apiToken': 'Cloudflare API Token',
      'apiTokenPermissionsHint':
          'The token needs account-level permission for Cloudflare Tunnel (Read, Edit) and Access: Apps and Policies (Read, Edit), scoped to every account you want to manage.',
      'test': 'TEST', 'save': 'Save', 'tokenSaved': 'Token saved!', 'saved': 'Saved!',
      'connectionSuccess': 'Connection successful! {count} account(s) found.',
      'connectionFailed': 'Connection failed. Invalid token.',
      'appTheme': 'App theme', 'themeDescription': 'Choose a fixed theme or automatically use the system theme.',
      'systemTheme': 'Use system theme', 'light': 'Light', 'dark': 'Dark',
      'language': 'Language', 'languageDescription': 'Choose the app language or use the system language.',
      'systemLanguage': 'Use system language',
      'changePassword': 'Change app password', 'currentPassword': 'Current password',
      'newPassword': 'New password', 'confirmNewPassword': 'Confirm new password',
      'password': 'Password', 'confirmPassword': 'Confirm password', 'updatePassword': 'UPDATE PASSWORD',
      'passwordIncorrect': 'Current password is incorrect!', 'passwordEmpty': 'The password cannot be empty.',
      'newPasswordEmpty': 'The new password cannot be empty!', 'passwordMismatch': 'Passwords do not match.',
      'passwordMismatchExclaim': 'Passwords do not match!', 'passwordUpdated': 'Password updated successfully!',
      'about': 'About the app', 'viewChangelog': 'VIEW VERSION HISTORY (CHANGELOG)',
      'versionHistory': 'Version history', 'changelogLoadError': 'Unable to load the changelog.\nDetails: {error}',
      'unableOpenLink': 'Unable to open the link.',
      'madeBy': 'Made by {name}',
      'aboutTagline': 'Infrastructure that works. Systems that keep standing.',
      'aboutDescription': 'Infrastructure, cloud, networking, and security.',
      'credentialsInvalid': 'Invalid credentials!',
      'biometricReason': 'Authenticate to manage your Cloudflare Zero Trust',
      'loginBiometric': 'LOGIN WITH BIOMETRICS', 'usePassword': 'Use password instead of biometrics',
      'login': 'LOGIN', 'createPassword': 'Create password', 'saveAndLogin': 'SAVE AND LOGIN',
      'updateError': 'Error updating: {error}', 'deleteError': 'Error deleting: {error}',
      'createError': 'Error creating: {error}',
      'cancel': 'Cancel', 'delete': 'Delete', 'retry': 'Retry',
      'tokenNotConfigured': 'Token not configured. Go to Settings.', 'configureToken': 'Configure token',
      'accounts': 'Accounts', 'switchAccount': 'Switch account',
      'pinAccount': 'Pin account', 'unpinAccount': 'Unpin account',
      'copyName': 'Copy name', 'copyId': 'Copy ID',
      'copiedToClipboard': 'Copied to clipboard.',
      'accountsLoadError': 'Error loading accounts: {error}',
      'noAccounts': 'No accounts found for this token.',
      'tunnels': 'Tunnels', 'accessApps': 'Access Apps',
      'searchTunnel': 'Search tunnel...', 'searchAccessApp': 'Search Access App...',
      'noTunnels': 'No tunnels found.', 'noTunnelsSearch': 'No tunnel matches the search.',
      'noAccessApps': 'No Access Apps found.', 'noAccessAppsSearch': 'No app matches the search.',
      'tunnelsLoadError': 'Error loading tunnels: {error}',
      'accessAppsLoadError': 'Error loading Access Apps: {error}',
      'tunnelStatusHealthy': 'Healthy', 'tunnelStatusDegraded': 'Degraded',
      'tunnelStatusDown': 'Down', 'tunnelStatusInactive': 'Inactive',
      'connectorsCount': '{count} connector(s)',
      'connectors': 'Active connectors', 'noConnectors': 'No active connectors. The tunnel is offline.',
      'routes': 'Routes (Public Hostname)', 'noRoutes': 'No routes configured.',
      'addRoute': 'Add route', 'editRoute': 'Edit route',
      'hostname': 'Hostname', 'destination': 'Destination',
      'deleteRouteConfirmTitle': 'Confirm deletion', 'deleteRouteConfirm': 'Delete the route {hostname}?',
      'advancedHttpSettings': 'Advanced settings (HTTP/HTTPS)',
      'noTLSVerify': 'Skip TLS/SSL verification of the origin',
      'noTLSVerifyHint': 'Only use if the origin has a self-signed or invalid certificate.',
      'originServerName': 'Certificate hostname (SNI)',
      'originServerNameHint': 'Hostname expected on the origin certificate',
      'matchSNItoHost': 'Match SNI to the route hostname',
      'httpHostHeader': 'HTTP Host header',
      'http2Origin': 'Attempt HTTP/2 to the origin',
      'disableChunkedEncoding': 'Disable chunked encoding',
      'noHappyEyeballs': 'Disable Happy Eyeballs (IPv4/IPv6)',
      'proxyType': 'Proxy type', 'proxyTypeNone': 'None',
      'caPool': 'Custom CA certificate', 'caPoolHint': 'Path to the .pem file on the server',
      'connectTimeout': 'Connect timeout', 'tlsTimeout': 'TLS handshake timeout',
      'tcpKeepAlive': 'TCP keep-alive interval',
      'keepAliveConnections': 'Max idle keep-alive connections',
      'keepAliveTimeout': 'Idle keep-alive timeout', 'secondsHint': 'seconds',
      'routeSaveError': 'Error saving route: {error}', 'routesLoadError': 'Error loading tunnel data: {error}',
      'newAccessApp': 'New Access App', 'name': 'Name', 'domain': 'Domain',
      'nameAndDomainRequired': 'Enter a name and domain.',
      'sessionDuration': 'Session duration', 'sessionDurationHint': 'e.g. 24h',
      'deleteAppConfirmTitle': 'Delete Access App',
      'deleteAppConfirm': 'Delete the Access App {name}? This removes access protection from the domain.',
      'policies': 'Policies', 'noPolicies': 'No policies configured. Without policies, access is denied by default.',
      'newPolicy': 'New policy', 'editPolicy': 'Edit policy', 'policyName': 'Policy name',
      'policyNameRequired': 'The policy name cannot be empty.',
      'decision': 'Action', 'decisionAllow': 'Allow', 'decisionDeny': 'Block',
      'decisionBypass': 'Bypass', 'decisionNonIdentity': 'Service Auth',
      'include': 'Include', 'exclude': 'Exclude', 'require': 'Require',
      'addRule': 'Add rule', 'ruleValueRequired': 'Fill in the value for every rule (or remove it).',
      'selectorEmail': 'Email', 'selectorEmailDomain': 'Email domain',
      'selectorEveryone': 'Everyone', 'selectorIp': 'IP range',
      'unsupportedRule':
          '{count} rule(s) not supported by this editor, preserved unchanged (manage them from the Cloudflare dashboard).',
      'policyIncludeRequired': 'At least one rule is required in Include.',
      'deletePolicyConfirmTitle': 'Confirm deletion', 'deletePolicyConfirm': 'Delete the policy {name}?',
      'policySaveError': 'Error saving policy: {error}',
    },
    'pt': {
      'appName': 'ZeroGate',
      'settings': 'Configurações', 'apiToken': 'Token da API Cloudflare',
      'apiTokenPermissionsHint':
          'O token precisa de permissão de conta para Cloudflare Tunnel (Leitura, Edição) e Access: Apps and Policies (Leitura, Edição), com acesso a todas as contas que deseja gerenciar.',
      'test': 'TESTAR', 'save': 'Salvar', 'tokenSaved': 'Token salvo!', 'saved': 'Salvo!',
      'connectionSuccess': 'Conexão bem-sucedida! {count} conta(s) encontrada(s).',
      'connectionFailed': 'Falha na conexão. Token inválido.',
      'appTheme': 'Tema do aplicativo',
      'themeDescription': 'Escolha um tema fixo ou use automaticamente o tema configurado no sistema.',
      'systemTheme': 'Usar tema do sistema', 'light': 'Claro', 'dark': 'Escuro', 'language': 'Idioma',
      'languageDescription': 'Escolha o idioma do aplicativo ou use o idioma do sistema.',
      'systemLanguage': 'Usar idioma do sistema',
      'changePassword': 'Alterar senha do app', 'currentPassword': 'Senha atual',
      'newPassword': 'Nova senha', 'confirmNewPassword': 'Confirmar nova senha',
      'password': 'Senha', 'confirmPassword': 'Confirmar senha', 'updatePassword': 'ATUALIZAR SENHA',
      'passwordIncorrect': 'Senha atual incorreta!', 'passwordEmpty': 'A senha não pode ser vazia.',
      'newPasswordEmpty': 'A nova senha não pode ser vazia!', 'passwordMismatch': 'As senhas não coincidem.',
      'passwordMismatchExclaim': 'As senhas não coincidem!', 'passwordUpdated': 'Senha atualizada com sucesso!',
      'about': 'Sobre o aplicativo', 'viewChangelog': 'VER HISTÓRICO DE VERSÕES (CHANGELOG)',
      'versionHistory': 'Histórico de versões',
      'changelogLoadError': 'Erro ao carregar o changelog.\nDetalhes: {error}',
      'unableOpenLink': 'Não foi possível abrir o link.',
      'madeBy': 'Feito por {name}',
      'aboutTagline': 'Infraestrutura que funciona. Sistemas que continuam de pé.',
      'aboutDescription': 'Infraestrutura, cloud, redes e segurança.',
      'credentialsInvalid': 'Credenciais inválidas!',
      'biometricReason': 'Autentique-se para gerenciar seu Cloudflare Zero Trust',
      'loginBiometric': 'ENTRAR COM BIOMETRIA', 'usePassword': 'Usar senha ao invés da biometria',
      'login': 'ENTRAR', 'createPassword': 'Criar senha', 'saveAndLogin': 'SALVAR E ENTRAR',
      'updateError': 'Erro ao atualizar: {error}', 'deleteError': 'Erro ao excluir: {error}',
      'createError': 'Erro ao criar: {error}',
      'cancel': 'Cancelar', 'delete': 'Excluir', 'retry': 'Tentar novamente',
      'tokenNotConfigured': 'Token não configurado. Vá em Configurações.', 'configureToken': 'Configurar token',
      'accounts': 'Contas', 'switchAccount': 'Trocar conta',
      'pinAccount': 'Fixar conta', 'unpinAccount': 'Desafixar conta',
      'copyName': 'Copiar nome', 'copyId': 'Copiar ID',
      'copiedToClipboard': 'Copiado para a área de transferência.',
      'accountsLoadError': 'Erro ao carregar contas: {error}',
      'noAccounts': 'Nenhuma conta encontrada para este token.',
      'tunnels': 'Túneis', 'accessApps': 'Access Apps',
      'searchTunnel': 'Pesquisar túnel...', 'searchAccessApp': 'Pesquisar Access App...',
      'noTunnels': 'Nenhum túnel encontrado.', 'noTunnelsSearch': 'Nenhum túnel corresponde à pesquisa.',
      'noAccessApps': 'Nenhum Access App encontrado.', 'noAccessAppsSearch': 'Nenhum app corresponde à pesquisa.',
      'tunnelsLoadError': 'Erro ao carregar túneis: {error}',
      'accessAppsLoadError': 'Erro ao carregar Access Apps: {error}',
      'tunnelStatusHealthy': 'Saudável', 'tunnelStatusDegraded': 'Degradado',
      'tunnelStatusDown': 'Inativo', 'tunnelStatusInactive': 'Não conectado',
      'connectorsCount': '{count} conector(es)',
      'connectors': 'Conectores ativos', 'noConnectors': 'Nenhum conector ativo. O túnel está offline.',
      'routes': 'Rotas (Public Hostname)', 'noRoutes': 'Nenhuma rota configurada.',
      'addRoute': 'Adicionar rota', 'editRoute': 'Editar rota',
      'hostname': 'Hostname', 'destination': 'Destino',
      'deleteRouteConfirmTitle': 'Confirmar exclusão', 'deleteRouteConfirm': 'Excluir a rota {hostname}?',
      'advancedHttpSettings': 'Configurações avançadas (HTTP/HTTPS)',
      'noTLSVerify': 'Ignorar verificação de TLS/SSL do destino',
      'noTLSVerifyHint': 'Use apenas se o destino tiver certificado autoassinado ou inválido.',
      'originServerName': 'Hostname do certificado (SNI)',
      'originServerNameHint': 'Hostname esperado no certificado do destino',
      'matchSNItoHost': 'Usar o hostname da rota como SNI',
      'httpHostHeader': 'Cabeçalho HTTP Host',
      'http2Origin': 'Tentar HTTP/2 com o destino',
      'disableChunkedEncoding': 'Desativar chunked encoding',
      'noHappyEyeballs': 'Desativar Happy Eyeballs (IPv4/IPv6)',
      'proxyType': 'Tipo de proxy', 'proxyTypeNone': 'Nenhum',
      'caPool': 'Certificado CA customizado', 'caPoolHint': 'Caminho do arquivo .pem no servidor',
      'connectTimeout': 'Timeout de conexão', 'tlsTimeout': 'Timeout de handshake TLS',
      'tcpKeepAlive': 'Intervalo de TCP keep-alive',
      'keepAliveConnections': 'Máx. conexões keep-alive ociosas',
      'keepAliveTimeout': 'Timeout de keep-alive ocioso', 'secondsHint': 'segundos',
      'routeSaveError': 'Erro ao salvar rota: {error}',
      'routesLoadError': 'Erro ao carregar dados do túnel: {error}',
      'newAccessApp': 'Novo Access App', 'name': 'Nome', 'domain': 'Domínio',
      'nameAndDomainRequired': 'Informe nome e domínio.',
      'sessionDuration': 'Duração da sessão', 'sessionDurationHint': 'ex: 24h',
      'deleteAppConfirmTitle': 'Excluir Access App',
      'deleteAppConfirm': 'Excluir o Access App {name}? Isso remove a proteção de acesso ao domínio.',
      'policies': 'Políticas',
      'noPolicies': 'Nenhuma política configurada. Sem políticas, o acesso é negado por padrão.',
      'newPolicy': 'Nova política', 'editPolicy': 'Editar política', 'policyName': 'Nome da política',
      'policyNameRequired': 'O nome da política não pode ser vazio.',
      'decision': 'Ação', 'decisionAllow': 'Permitir', 'decisionDeny': 'Bloquear',
      'decisionBypass': 'Ignorar (Bypass)', 'decisionNonIdentity': 'Autenticação de serviço',
      'include': 'Incluir', 'exclude': 'Excluir', 'require': 'Exigir',
      'addRule': 'Adicionar regra', 'ruleValueRequired': 'Preencha o valor de todas as regras (ou remova-as).',
      'selectorEmail': 'E-mail', 'selectorEmailDomain': 'Domínio de e-mail',
      'selectorEveryone': 'Todos', 'selectorIp': 'Intervalo de IP',
      'unsupportedRule':
          '{count} regra(s) não suportada(s) por este editor, preservada(s) sem alteração (gerencie pelo painel Cloudflare).',
      'policyIncludeRequired': 'É necessária ao menos uma regra em Incluir.',
      'deletePolicyConfirmTitle': 'Confirmar exclusão', 'deletePolicyConfirm': 'Excluir a política {name}?',
      'policySaveError': 'Erro ao salvar política: {error}',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
