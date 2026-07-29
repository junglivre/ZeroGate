import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static final Map<String, String> _changelogCache = {};
  String _changelogContent = '';
  bool _isLoading = true;
  bool _hasError = false;
  String? _loadedLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_loadedLanguageCode != languageCode) {
      _loadChangelog();
    }
  }

  Future<void> _loadChangelog() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    _loadedLanguageCode = languageCode;
    try {
      final content = _changelogCache[languageCode] ??
          await rootBundle.loadString(
              'assets/changelog/CHANGELOG_$languageCode.md');
      _changelogCache[languageCode] = content;
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _changelogContent = content;
        _hasError = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _loadedLanguageCode != languageCode) return;
      setState(() {
        _changelogContent = context.l10n.text('changelogLoadError', values: {'error': '$e'});
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('unableOpenLink'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context);
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.text('versionHistory')),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: _hasError
                      ? Text(_changelogContent)
                      : MarkdownBody(
                          data: _changelogContent,
                          selectable: true,
                          onTapLink: (text, href, title) => _openLink(href),
                        ),
                ),
        ),
      ),
    );
  }
}
