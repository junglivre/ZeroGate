import 'cloudflare_api.dart';

/// Cloudflare Tunnel (`cfd_tunnel`) API: list tunnels, inspect their active
/// connections and manage the ingress rules (Public Hostname routes) that
/// decide which local service each published hostname points to.
class TunnelsApi {
  /// Streams the account's tunnels one page at a time, so the tunnels
  /// screen can render results as they arrive instead of waiting for every
  /// page to load.
  static Stream<dynamic> streamTunnels(String accountId) =>
      CloudflareApi.streamPaginated(
        '/accounts/$accountId/cfd_tunnel',
        extraParams: const {'is_deleted': 'false'},
      );

  static Future<List<dynamic>> listTunnels(String accountId) async {
    final tunnels = <dynamic>[];
    await for (final tunnel in streamTunnels(accountId)) {
      tunnels.add(tunnel);
    }
    return tunnels;
  }

  /// Active connectors/colos for a tunnel. Read-only: connectors are managed
  /// by the `cloudflared` daemon, not by this app.
  static Future<List<dynamic>> getTunnelConnections(
      String accountId, String tunnelId) async {
    final json = await CloudflareApi.getJson(
      '/accounts/$accountId/cfd_tunnel/$tunnelId/connections',
    );
    final result = json['result'];
    return result is List ? result : <dynamic>[];
  }

  /// Private Network routes (CIDR routing for WARP clients) across the
  /// whole account. A single fetch is reused to both list the routes
  /// assigned to one tunnel and detect whether a route's CIDR is also
  /// routed by a *different* tunnel (surfaced as "shared" in the tunnel
  /// detail screen).
  static Future<List<dynamic>> listPrivateNetworkRoutes(
      String accountId) async {
    final routes = <dynamic>[];
    await for (final route in CloudflareApi.streamPaginated(
      '/accounts/$accountId/teamnet/routes',
      extraParams: const {'is_deleted': 'false'},
    )) {
      routes.add(route);
    }
    return routes;
  }

  /// Ingress rules (Public Hostname routes) currently configured for the
  /// tunnel. Returns an empty list if the tunnel has no remote configuration
  /// yet.
  static Future<List<dynamic>> getIngressRules(
      String accountId, String tunnelId) async {
    final json = await CloudflareApi.getJson(
      '/accounts/$accountId/cfd_tunnel/$tunnelId/configurations',
    );
    final config = json['result']?['config'];
    final ingress = config?['ingress'];
    return ingress is List ? List<dynamic>.from(ingress) : <dynamic>[];
  }

  /// Replaces the tunnel's ingress rules. `rules` must not include the
  /// catch-all entry — it is appended automatically so every saved
  /// configuration stays valid (Cloudflare requires the last ingress rule to
  /// have no hostname).
  static Future<void> saveIngressRules(
    String accountId,
    String tunnelId,
    List<Map<String, dynamic>> rules,
  ) async {
    await CloudflareApi.put(
      '/accounts/$accountId/cfd_tunnel/$tunnelId/configurations',
      {
        'config': {
          'ingress': [
            ...rules,
            {'service': 'http_status:404'},
          ],
        },
      },
    );
  }
}
