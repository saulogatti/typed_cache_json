import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:typed_cache_json/typed_cache_json.dart';

/// Opens a JSON file cache and a small demo of the public API.
///
/// [WidgetsFlutterBinding.ensureInitialized] is required before [create],
/// because the cache path comes from `path_provider`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logs = ValueNotifier<String?>(null);
  final cache = await create(
    location: CacheLocation.support,
    subdir: 'typed_cache_json_example',
    fileName: 'cache.json',
    logger: (message, error, _) {
      logs.value = error == null ? message : '$message ($error)';
    },
  );

  runApp(CacheExampleApp(cache: cache, logs: logs));
}

/// Short lifetime used by the "expire soon" switch.
const _shortTtl = Duration(seconds: 20);

String _firstLine(Exception error) {
  final line = error.toString().split('\n').first.trim();
  return line.isEmpty ? 'Cache operation failed.' : line;
}

String? _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  return null;
}

/// Interactive tour of put, get, getOrFetch, tags, TTL, and purge.
class CacheDemoPage extends StatefulWidget {
  /// Cache shared with the rest of the example.
  final TypedCache<String, Map<String, dynamic>> cache;

  /// Failure messages reported by the cache logger.
  final ValueNotifier<String?> logs;

  /// Creates the demo page.
  const CacheDemoPage({super.key, required this.cache, required this.logs});

  @override
  State<CacheDemoPage> createState() => _CacheDemoPageState();
}

/// Demo application for `typed_cache_json`.
class CacheExampleApp extends StatelessWidget {
  /// Cache created with [create] and the built-in JSON codec.
  final TypedCache<String, Map<String, dynamic>> cache;

  /// Failure messages reported by the cache logger.
  final ValueNotifier<String?> logs;

  /// Creates the example app around an already opened [cache].
  const CacheExampleApp({super.key, required this.cache, required this.logs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'typed_cache_json example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E6B)),
      ),
      home: CacheDemoPage(cache: cache, logs: logs),
    );
  }
}

class _CacheDemoPageState extends State<CacheDemoPage> {
  final _keyController = TextEditingController(text: 'note-1');
  final _valueController = TextEditingController(text: 'Hello, cache');
  final _tags = <String>{'notes'};

  List<Map<String, dynamic>> _entries = const [];
  Map<String, dynamic>? _greeting;
  String? _greetingStatus;
  bool _expireSoon = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _greeting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('typed_cache_json'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'One JSON file in the application support directory, '
                'at typed_cache_json_example/cache.json. '
                'Values use the ${widget.cache.defaultCodec.typeId} codec.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Save a value',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('notes'),
                          selected: _tags.contains('notes'),
                          onSelected: _busy
                              ? null
                              : (selected) => _toggleTag('notes', selected),
                        ),
                        FilterChip(
                          label: const Text('draft'),
                          selected: _tags.contains('draft'),
                          onSelected: _busy
                              ? null
                              : (selected) => _toggleTag('draft', selected),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expire after 20 seconds'),
                      value: _expireSoon,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _expireSoon = value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busy ? null : () => unawaited(_save()),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Cache-aside',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'getOrFetch returns the stored greeting, or fetches and stores it on a miss.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => unawaited(_loadGreeting()),
                      child: const Text('Load greeting'),
                    ),
                    if (greeting != null) ...[
                      const SizedBox(height: 12),
                      Text(_readString(greeting, 'text') ?? ''),
                      if (_greetingStatus != null)
                        Text(
                          _greetingStatus!,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (_readString(greeting, 'cachedAt')
                          case final String cachedAt)
                        Text(
                          'cachedAt: $cachedAt',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Cached entries',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_entries.isEmpty)
                      const Text(
                        'Nothing stored yet. Saved values stay on disk between runs.',
                      )
                    else
                      ..._entryTiles(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_run(() => _sync())),
                          child: const Text('Refresh'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_purgeExpired()),
                          child: const Text('Purge expired'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_invalidateDrafts()),
                          child: const Text('Invalidate draft'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => unawaited(_clear()),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.logs.removeListener(_onLog);
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.logs.addListener(_onLog);
    unawaited(_sync());
  }

  Future<void> _clear() async {
    await _run(() async {
      await widget.cache.clear();
      _showMessage('Cache cleared.');
      await _sync();
    });
  }

  List<Widget> _entryTiles() {
    final tiles = <Widget>[];
    for (final entry in _entries) {
      final key = _readString(entry, 'key');
      if (key == null) {
        continue;
      }
      tiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(key),
          subtitle: Text(_readString(entry, 'text') ?? ''),
          trailing: IconButton(
            tooltip: 'Remove',
            onPressed: _busy ? null : () => unawaited(_remove(key)),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      );
    }
    return tiles;
  }

  Future<Map<String, dynamic>> _fetchGreeting() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return {
      'key': 'greeting',
      'text': 'Hello from typed_cache_json',
      'cachedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _invalidateDrafts() async {
    await _run(() async {
      await widget.cache.invalidateByTag('draft');
      _showMessage('Invalidated the "draft" tag.');
      await _sync();
    });
  }

  Future<void> _loadGreeting() async {
    await _run(() async {
      final wasCached = await widget.cache.contains('greeting');
      await widget.cache.getOrFetch(
        'greeting',
        fetch: _fetchGreeting,
        ttl: const Duration(minutes: 10),
        tags: const {'demo'},
      );
      await _sync(greetingFromCache: wasCached);
    });
  }

  void _onLog() {
    final message = widget.logs.value;
    if (message == null) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _purgeExpired() async {
    await _run(() async {
      final removed = await widget.cache.purgeExpired();
      _showMessage(
        'Removed $removed expired ${removed == 1 ? 'entry' : 'entries'}.',
      );
      await _sync();
    });
  }

  Future<void> _remove(String key) async {
    await _run(() async {
      await widget.cache.remove(key);
      _showMessage('Removed "$key".');
      await _sync();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (error) {
      _showMessage(_firstLine(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    final text = _valueController.text.trim();
    if (key.isEmpty || text.isEmpty) {
      _showMessage('Enter a key and a value.');
      return;
    }

    await _run(() async {
      await widget.cache.put(
        key,
        {'key': key, 'text': text},
        ttl: _expireSoon ? _shortTtl : null,
        tags: Set<String>.of(_tags),
      );
      _showMessage('Saved "$key".');
      await _sync();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sync({bool? greetingFromCache}) async {
    final entries = await widget.cache.getAll();
    final greeting = await widget.cache.get('greeting');
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _greeting = greeting;
      if (greeting == null) {
        _greetingStatus = null;
      } else if (greetingFromCache != null) {
        _greetingStatus = greetingFromCache
            ? 'Returned from cache.'
            : 'Fetched, then stored.';
      }
    });
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      if (selected) {
        _tags.add(tag);
      } else {
        _tags.remove(tag);
      }
    });
  }
}

class _Section extends StatelessWidget {
  final String title;

  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
