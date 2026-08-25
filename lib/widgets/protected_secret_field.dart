import 'package:flutter/material.dart';

class ProtectedSecretField extends StatefulWidget {
  const ProtectedSecretField({
    super.key,
    required this.controller,
    required this.authorizeReveal,
    required this.revealTooltip,
    required this.hideTooltip,
  });

  final TextEditingController controller;
  final Future<bool> Function() authorizeReveal;
  final String revealTooltip;
  final String hideTooltip;

  @override
  State<ProtectedSecretField> createState() => _ProtectedSecretFieldState();
}

class _ProtectedSecretFieldState extends State<ProtectedSecretField>
    with WidgetsBindingObserver {
  bool _obscureText = true;
  bool _authorizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_obscureText && mounted) {
      setState(() => _obscureText = true);
    }
  }

  Future<void> _toggleVisibility() async {
    if (!_obscureText) {
      setState(() => _obscureText = true);
      return;
    }
    if (_authorizing) return;

    setState(() => _authorizing = true);
    final authorized = await widget.authorizeReveal();
    if (!mounted) return;
    setState(() {
      _authorizing = false;
      if (authorized) _obscureText = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        suffixIcon: _authorizing
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip:
                    _obscureText ? widget.revealTooltip : widget.hideTooltip,
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: _toggleVisibility,
              ),
      ),
    );
  }
}
