import 'cloudflare_api.dart';

/// Cloudflare DNS API used for the proxied CNAME records that make tunnel
/// public hostnames reachable.
class DnsApi {
  static Future<List<dynamic>> listZones(String accountId) async {
    final zones = <dynamic>[];
    await for (final zone in CloudflareApi.streamPaginated(
      '/zones',
      extraParams: {'account.id': accountId},
    )) {
      zones.add(zone);
    }
    return zones;
  }

  static Future<List<dynamic>> listRecords(
    String zoneId, {
    Map<String, String> filters = const {},
  }) async {
    final records = <dynamic>[];
    await for (final record in CloudflareApi.streamPaginated(
      '/zones/$zoneId/dns_records',
      extraParams: filters,
    )) {
      records.add(record);
    }
    return records;
  }

  static Future<Map<String, dynamic>> createRecord(
    String zoneId,
    Map<String, dynamic> data,
  ) =>
      CloudflareApi.post('/zones/$zoneId/dns_records', data);

  static Future<Map<String, dynamic>> updateRecord(
    String zoneId,
    String recordId,
    Map<String, dynamic> data,
  ) =>
      CloudflareApi.put('/zones/$zoneId/dns_records/$recordId', data);

  static Future<void> deleteRecord(String zoneId, String recordId) =>
      CloudflareApi.delete('/zones/$zoneId/dns_records/$recordId');
}
