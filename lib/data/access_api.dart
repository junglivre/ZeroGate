import 'cloudflare_api.dart';

/// Cloudflare Access API: self-hosted Applications (published apps) and the
/// policies attached to each one. Uses the per-application policies
/// endpoint (`/access/apps/{app_id}/policies`) rather than the reusable
/// policy library, which is simpler and matches how most self-hosted apps
/// are configured from the dashboard.
class AccessApi {
  /// Streams the account's Access Apps one page at a time, so the Access
  /// Apps screen can render results as they arrive instead of waiting for
  /// every page to load.
  static Stream<dynamic> streamAccessApps(String accountId) =>
      CloudflareApi.streamPaginated('/accounts/$accountId/access/apps');

  static Future<List<dynamic>> listAccessApps(String accountId) async {
    final apps = <dynamic>[];
    await for (final app in streamAccessApps(accountId)) {
      apps.add(app);
    }
    return apps;
  }

  static Future<Map<String, dynamic>> getAccessApp(
      String accountId, String appId) async {
    final json = await CloudflareApi.getJson(
      '/accounts/$accountId/access/apps/$appId',
    );
    return json['result'];
  }

  static Future<void> createAccessApp(
      String accountId, Map<String, dynamic> data) async {
    await CloudflareApi.post('/accounts/$accountId/access/apps', data);
  }

  static Future<void> updateAccessApp(
      String accountId, String appId, Map<String, dynamic> data) async {
    await CloudflareApi.put(
        '/accounts/$accountId/access/apps/$appId', data);
  }

  static Future<void> deleteAccessApp(String accountId, String appId) async {
    await CloudflareApi.delete('/accounts/$accountId/access/apps/$appId');
  }

  static Future<List<dynamic>> listAccessPolicies(
      String accountId, String appId) async {
    final policies = <dynamic>[];
    await for (final policy in CloudflareApi.streamPaginated(
        '/accounts/$accountId/access/apps/$appId/policies')) {
      policies.add(policy);
    }
    return policies;
  }

  static Future<void> createAccessPolicy(
    String accountId,
    String appId,
    Map<String, dynamic> data,
  ) async {
    await CloudflareApi.post(
      '/accounts/$accountId/access/apps/$appId/policies',
      data,
    );
  }

  static Future<void> updateAccessPolicy(
    String accountId,
    String appId,
    String policyId,
    Map<String, dynamic> data,
  ) async {
    await CloudflareApi.put(
      '/accounts/$accountId/access/apps/$appId/policies/$policyId',
      data,
    );
  }

  static Future<void> deleteAccessPolicy(
    String accountId,
    String appId,
    String policyId,
  ) async {
    await CloudflareApi.delete(
      '/accounts/$accountId/access/apps/$appId/policies/$policyId',
    );
  }
}
