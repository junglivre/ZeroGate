import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../data/ingress_rule_validator.dart';
import '../l10n/app_localizations.dart';

/// The `originRequest` keys this screen knows how to edit. Anything else
/// already present on the rule (e.g. a JWT `access` validation block set up
/// elsewhere) is preserved untouched via [_RouteEditorScreenState._passthroughOriginRequest].
const _kKnownOriginRequestKeys = {
  'noTLSVerify',
  'originServerName',
  'matchSNItoHost',
  'httpHostHeader',
  'http2Origin',
  'disableChunkedEncoding',
  'noHappyEyeballs',
  'proxyType',
  'caPool',
  'connectTimeout',
  'tlsTimeout',
  'tcpKeepAlive',
  'keepAliveConnections',
  'keepAliveTimeout',
};

/// Creates or edits a single tunnel ingress rule (a "published app" route):
/// hostname, destination (type + address) and, for HTTP/HTTPS destinations,
/// the advanced origin request settings Cloudflare's dashboard exposes under
/// "Additional application settings" (TLS verification, SNI/host header,
/// timeouts, keep-alive, HTTP/2, proxying).
///
/// Returns the built rule map via `Navigator.pop` (or `null` if cancelled).
/// Saving all routes together (via `TunnelsApi.saveIngressRules`) is the
/// caller's responsibility.
class RouteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? route;

  const RouteEditorScreen({super.key, this.route});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final _hostnameController = TextEditingController();
  final _addressController = TextEditingController();
  String _scheme = 'http';

  bool _noTLSVerify = false;
  bool _matchSNItoHost = false;
  bool _http2Origin = false;
  bool _disableChunkedEncoding = false;
  bool _noHappyEyeballs = false;
  String _proxyType = '';
  final _originServerNameController = TextEditingController();
  final _httpHostHeaderController = TextEditingController();
  final _caPoolController = TextEditingController();
  final _connectTimeoutController = TextEditingController();
  final _tlsTimeoutController = TextEditingController();
  final _tcpKeepAliveController = TextEditingController();
  final _keepAliveConnectionsController = TextEditingController();
  final _keepAliveTimeoutController = TextEditingController();

  Map<String, dynamic> _passthroughOriginRequest = {};

  bool get _isEditing => widget.route != null;
  bool get _isHttpScheme => IngressRuleValidator.isHttpScheme(_scheme);

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route != null) {
      _hostnameController.text = route['hostname'] ?? '';
      final parsed = IngressRuleValidator.parseService(route['service'] ?? '');
      _scheme = kIngressServiceSchemes.contains(parsed.scheme)
          ? parsed.scheme
          : 'http';
      _addressController.text = parsed.address;

      final originRequest = route['originRequest'];
      if (originRequest is Map) {
        _passthroughOriginRequest = Map<String, dynamic>.from(originRequest)
          ..removeWhere((key, _) => _kKnownOriginRequestKeys.contains(key));

        _noTLSVerify = originRequest['noTLSVerify'] == true;
        _matchSNItoHost = originRequest['matchSNItoHost'] == true;
        _http2Origin = originRequest['http2Origin'] == true;
        _disableChunkedEncoding = originRequest['disableChunkedEncoding'] == true;
        _noHappyEyeballs = originRequest['noHappyEyeballs'] == true;
        _proxyType = originRequest['proxyType']?.toString() ?? '';
        _originServerNameController.text =
            originRequest['originServerName']?.toString() ?? '';
        _httpHostHeaderController.text =
            originRequest['httpHostHeader']?.toString() ?? '';
        _caPoolController.text = originRequest['caPool']?.toString() ?? '';
        _connectTimeoutController.text =
            originRequest['connectTimeout']?.toString() ?? '';
        _tlsTimeoutController.text =
            originRequest['tlsTimeout']?.toString() ?? '';
        _tcpKeepAliveController.text =
            originRequest['tcpKeepAlive']?.toString() ?? '';
        _keepAliveConnectionsController.text =
            originRequest['keepAliveConnections']?.toString() ?? '';
        _keepAliveTimeoutController.text =
            originRequest['keepAliveTimeout']?.toString() ?? '';
      }
    } else {
      _scheme = 'http';
    }
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _addressController.dispose();
    _originServerNameController.dispose();
    _httpHostHeaderController.dispose();
    _caPoolController.dispose();
    _connectTimeoutController.dispose();
    _tlsTimeoutController.dispose();
    _tcpKeepAliveController.dispose();
    _keepAliveConnectionsController.dispose();
    _keepAliveTimeoutController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
    ));
  }

  void _save() {
    final hostname = _hostnameController.text.trim();
    final address = _addressController.text.trim();

    final hostnameError = IngressRuleValidator.validateHostname(hostname);
    if (hostnameError != null) return _showError(hostnameError);

    final addressError = IngressRuleValidator.validateAddress(_scheme, address);
    if (addressError != null) return _showError(addressError);

    final numericFields = <String, TextEditingController>{
      'connectTimeout': _connectTimeoutController,
      'tlsTimeout': _tlsTimeoutController,
      'tcpKeepAlive': _tcpKeepAliveController,
      'keepAliveConnections': _keepAliveConnectionsController,
      'keepAliveTimeout': _keepAliveTimeoutController,
    };
    for (final entry in numericFields.entries) {
      final error = IngressRuleValidator.validatePositiveInt(entry.value.text);
      if (error != null) return _showError(error);
    }

    final result = <String, dynamic>{
      'hostname': hostname,
      'service': IngressRuleValidator.buildService(_scheme, address),
    };

    final originRequest = <String, dynamic>{..._passthroughOriginRequest};
    if (_isHttpScheme) {
      if (_noTLSVerify) originRequest['noTLSVerify'] = true;
      if (_matchSNItoHost) originRequest['matchSNItoHost'] = true;
      if (_http2Origin) originRequest['http2Origin'] = true;
      if (_disableChunkedEncoding) originRequest['disableChunkedEncoding'] = true;
      if (_noHappyEyeballs) originRequest['noHappyEyeballs'] = true;
      if (_proxyType.isNotEmpty) originRequest['proxyType'] = _proxyType;
      if (_originServerNameController.text.trim().isNotEmpty) {
        originRequest['originServerName'] = _originServerNameController.text.trim();
      }
      if (_httpHostHeaderController.text.trim().isNotEmpty) {
        originRequest['httpHostHeader'] = _httpHostHeaderController.text.trim();
      }
      if (_caPoolController.text.trim().isNotEmpty) {
        originRequest['caPool'] = _caPoolController.text.trim();
      }
      for (final entry in numericFields.entries) {
        final text = entry.value.text.trim();
        if (text.isNotEmpty) originRequest[entry.key] = int.parse(text);
      }
    }

    if (originRequest.isNotEmpty) {
      result['originRequest'] = originRequest;
    }

    Navigator.pop(context, result);
  }

  Widget _numberField(TextEditingController controller, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(context.l10n.text('advancedHttpSettings'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.text('noTLSVerify')),
            subtitle: Text(context.l10n.text('noTLSVerifyHint')),
            value: _noTLSVerify,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _noTLSVerify = v),
          ),
          TextField(
            controller: _originServerNameController,
            decoration: InputDecoration(
              labelText: context.l10n.text('originServerName'),
              hintText: context.l10n.text('originServerNameHint'),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.text('matchSNItoHost')),
            value: _matchSNItoHost,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _matchSNItoHost = v),
          ),
          TextField(
            controller: _httpHostHeaderController,
            decoration: InputDecoration(
              labelText: context.l10n.text('httpHostHeader'),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.text('http2Origin')),
            value: _http2Origin,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _http2Origin = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.text('disableChunkedEncoding')),
            value: _disableChunkedEncoding,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _disableChunkedEncoding = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.text('noHappyEyeballs')),
            value: _noHappyEyeballs,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _noHappyEyeballs = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _proxyType,
            decoration:
                InputDecoration(labelText: context.l10n.text('proxyType')),
            items: [
              DropdownMenuItem(value: '', child: Text(context.l10n.text('proxyTypeNone'))),
              const DropdownMenuItem(value: 'socks', child: Text('SOCKS')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _proxyType = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caPoolController,
            decoration: InputDecoration(
              labelText: context.l10n.text('caPool'),
              hintText: context.l10n.text('caPoolHint'),
            ),
          ),
          const SizedBox(height: 12),
          _numberField(_connectTimeoutController,
              context.l10n.text('connectTimeout'), context.l10n.text('secondsHint')),
          _numberField(_tlsTimeoutController, context.l10n.text('tlsTimeout'),
              context.l10n.text('secondsHint')),
          _numberField(_tcpKeepAliveController, context.l10n.text('tcpKeepAlive'),
              context.l10n.text('secondsHint')),
          _numberField(_keepAliveConnectionsController,
              context.l10n.text('keepAliveConnections'), ''),
          _numberField(_keepAliveTimeoutController,
              context.l10n.text('keepAliveTimeout'), context.l10n.text('secondsHint')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? context.l10n.text('editRoute')
            : context.l10n.text('addRoute')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostnameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: context.l10n.text('hostname'),
              hintText: 'app.exemplo.com',
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.text('destination'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: _scheme,
                  decoration: const InputDecoration(isDense: true),
                  items: kIngressServiceSchemes
                      .map((scheme) => DropdownMenuItem(
                            value: scheme,
                            child: Text(scheme),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _scheme = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: IngressRuleValidator.isUnixScheme(_scheme)
                        ? '/var/run/app.sock'
                        : 'localhost:8080',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isHttpScheme) _buildAdvancedSection(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(context.l10n.text('save'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
