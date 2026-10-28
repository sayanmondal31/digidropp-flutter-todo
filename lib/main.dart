import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Settings come from .env (bundled as an asset). It isn't committed: Digidropp builds create it from the
// variables set on the Automatic builds page, and local runs use a copy of .env.example.
class AppConfig {
  const AppConfig({required this.title, required this.environment, required this.accent, required this.apiUrl});

  final String title;
  final String environment;
  final Color accent;
  final String apiUrl;

  static AppConfig fromEnv() {
    String read(String key, String fallback) {
      final value = dotenv.isInitialized ? dotenv.maybeGet(key)?.trim() : null;
      return value == null || value.isEmpty ? fallback : value;
    }

    final hex = int.tryParse(read('ACCENT_COLOR', '6366F1').replaceAll('#', ''), radix: 16) ?? 0x6366F1;
    return AppConfig(
      title: read('APP_TITLE', 'Todos'),
      environment: read('ENVIRONMENT', 'not set'),
      accent: Color(0xFF000000 | hex),
      apiUrl: read('API_URL', 'not set'),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var envLoaded = true;
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    envLoaded = false;
  }
  runApp(TodoApp(config: AppConfig.fromEnv(), envLoaded: envLoaded));
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.config, required this.envLoaded});

  final AppConfig config;
  final bool envLoaded;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: config.accent)),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: config.accent, brightness: Brightness.dark)),
      home: TodoScreen(config: config, envLoaded: envLoaded),
    );
  }
}

class Todo {
  Todo({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory Todo.fromJson(Map<String, dynamic> json) =>
      Todo(id: json['id'] as String, title: json['title'] as String, done: json['done'] as bool? ?? false);
}

enum Filter { all, active, done }

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.config, required this.envLoaded});

  final AppConfig config;
  final bool envLoaded;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  static const _storageKey = 'todos';

  final _controller = TextEditingController();
  List<Todo> _todos = [];
  Filter _filter = Filter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (!mounted) return;
    setState(() {
      _todos = saved == null
          ? []
          : (jsonDecode(saved) as List).map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_todos.map((t) => t.toJson()).toList()));
  }

  void _add() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    setState(() => _todos.insert(0, Todo(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title)));
    _controller.clear();
    _save();
  }

  void _toggle(Todo todo) {
    setState(() => todo.done = !todo.done);
    _save();
  }

  void _delete(Todo todo) {
    final index = _todos.indexOf(todo);
    setState(() => _todos.remove(todo));
    _save();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${todo.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _todos.insert(index.clamp(0, _todos.length), todo));
            _save();
          },
        ),
      ));
  }

  void _clearDone() {
    setState(() => _todos.removeWhere((t) => t.done));
    _save();
  }

  void _showBuildInfo() {
    final config = widget.config;
    final accentHex = (config.accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About this build', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.envLoaded
                    ? 'These values come from the .env file created at build time.'
                    : 'No .env file was bundled, so the app is using its defaults.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'APP_TITLE', value: config.title),
              _InfoRow(label: 'ENVIRONMENT', value: config.environment),
              _InfoRow(label: 'ACCENT_COLOR', value: '#$accentHex'),
              _InfoRow(label: 'API_URL', value: config.apiUrl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = switch (_filter) {
      Filter.all => _todos,
      Filter.active => _todos.where((t) => !t.done).toList(),
      Filter.done => _todos.where((t) => t.done).toList(),
    };
    final remaining = _todos.where((t) => !t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              label: Text(widget.config.environment.toUpperCase()),
              labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
              backgroundColor: scheme.primaryContainer,
              side: BorderSide.none,
              onPressed: _showBuildInfo,
            ),
          ),
          IconButton(icon: const Icon(Icons.info_outline), tooltip: 'About this build', onPressed: _showBuildInfo),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.envLoaded)
              MaterialBanner(
                content: const Text("No .env file in this build. Add variables on Digidropp to set the app's config."),
                actions: [TextButton(onPressed: _showBuildInfo, child: const Text('Details'))],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(hintText: 'What needs doing?', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _add, icon: const Icon(Icons.add), tooltip: 'Add'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SegmentedButton<Filter>(
                    segments: const [
                      ButtonSegment(value: Filter.all, label: Text('All')),
                      ButtonSegment(value: Filter.active, label: Text('Active')),
                      ButtonSegment(value: Filter.done, label: Text('Done')),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _filter = s.first),
                  ),
                  const Spacer(),
                  if (_todos.any((t) => t.done)) TextButton(onPressed: _clearDone, child: const Text('Clear done')),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? Center(
                          child: Text(
                            _todos.isEmpty ? 'Nothing to do yet. Add your first todo above.' : 'Nothing here.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final todo = visible[i];
                            return Dismissible(
                              key: ValueKey(todo.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                color: scheme.errorContainer,
                                child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                              ),
                              onDismissed: (_) => _delete(todo),
                              child: CheckboxListTile(
                                value: todo.done,
                                onChanged: (_) => _toggle(todo),
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  todo.title,
                                  style: todo.done
                                      ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$remaining left · built by Digidropp',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
