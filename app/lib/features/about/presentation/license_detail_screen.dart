import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/license_entry.dart';

/// Renders a single license body in a [SelectableText] so users can copy
/// the content.
///
/// Spec `oss-license-notices` Requirement "License list screen displays
/// all dependencies" — detail uses `SelectableText`.
///
/// Two construction modes:
///   - `LicenseDetailScreen.forEntry(entry)` — render a [LicenseEntry]
///   - `LicenseDetailScreen(assetPath: ...)` — render bundled asset text
///     (e.g. `assets/legal/LICENSE`, `assets/legal/LGPL-2.1.txt`)
class LicenseDetailScreen extends StatelessWidget {
  const LicenseDetailScreen({
    super.key,
    required this.title,
    this.assetPath,
    this.body,
    this.subtitle,
  }) : assert(
         assetPath != null || body != null,
         'one of assetPath / body must be provided',
       );

  LicenseDetailScreen.forEntry(LicenseEntry entry, {Key? key})
    : this(
        key: key,
        title: entry.name,
        subtitle: entry.version != null ? 'version ${entry.version}' : null,
        body: entry.licenseText,
      );

  final String title;
  final String? assetPath;
  final String? body;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _Body(assetPath: assetPath, body: body, subtitle: subtitle),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({this.assetPath, this.body, this.subtitle});
  final String? assetPath;
  final String? body;
  final String? subtitle;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.assetPath != null) {
      _future = rootBundle.loadString(widget.assetPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.body != null) {
      return _render(widget.body!);
    }
    return FutureBuilder<String>(
      future: _future,
      builder: (BuildContext ctx, AsyncSnapshot<String> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('ライセンス本文の読み込みに失敗しました: ${snap.error}'),
            ),
          );
        }
        return _render(snap.data!);
      },
    );
  }

  Widget _render(String text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
