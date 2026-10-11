import 'profile_page.dart';
import 'startup_page.dart';
import 'dart:async';
import 'account_panel.dart';
import 'cloud_backend.dart';
import 'package:file_picker/file_picker.dart';
import 'glass.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'store.dart';
import 'workflow.dart';
import 'scanner.dart';
import 'tool_icon.dart';
import 'workspace_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(StartupApp(load: initializeWorkspace));
}

Future<AppStore> initializeWorkspace() async {
  await SupabaseBackend.initialize();
  final store = AppStore(
    await SharedPreferences.getInstance(),
    cloud: SupabaseBackend.active,
  );
  await store.initialize();
  SupabaseBackend.active?.addListener(() {
    // Run database calls outside the auth stream callback.
    scheduleMicrotask(() => unawaited(store.switchAccount()));
  });
  return store;
}

class AliDocsApp extends StatelessWidget {
  final AppStore store;
  const AliDocsApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (_, _) => MaterialApp(
      key: ValueKey(store.accountId ?? 'guest'),
      title: 'SUPER - Docs',
      debugShowCheckedModeBanner: false,
      themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      builder: (context, child) =>
          GlassBackground(child: child ?? const SizedBox()),
      home: HomeScreen(store: store),
    ),
  );
  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandPurple,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFD3B6FF) : brandPurple,
          secondary: dark ? const Color(0xFFD3B6FF) : brandPurple,
          surface: dark ? const Color(0xFF251C34) : Colors.white,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'sans-serif',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? const Color(0xE6251C34)
            : const Color(0xE6FFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark
            ? const Color(0xE6251C34)
            : const Color(0xE6FFFFFF),
        indicatorColor: dark
            ? const Color(0xFF4C2A74)
            : const Color(0xFFEDE2FF),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandPurple,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF251C34) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: dark ? Colors.white12 : const Color(0xFFEDE7FA),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEDE7FA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEDE7FA)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String query = '', category = 'All tools';
  bool favoritesOnly = false;
  static const labels = ['PDF tools', 'Image tools', 'Scanner', 'My files'];
  static const icons = [
    Icons.description_outlined,
    Icons.image_outlined,
    Icons.document_scanner_outlined,
    Icons.folder_outlined,
  ];
  Future<void> openProfile() async {
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(store: widget.store)),
    );
    if (mounted && action == 'files') setState(() => tab = 3);
  }

  void openTool(DocTool tool) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ToolScreen(tool: tool, store: widget.store),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    if (viewportWidth < 120) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final wide = viewportWidth >= 900;
    return Scaffold(
      extendBody: true,
      body: Row(
        children: [
          if (wide)
            Container(
              width: 226,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: const Border(
                  right: BorderSide(color: Color(0xFFEDE7FA)),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(26, 32, 16, 38),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Brand()),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 26),
                        child: Text(
                          'YOUR WORKSPACE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: ListTile(
                            selected: tab == i,
                            selectedColor: brandPurple,
                            selectedTileColor: brandPurple.withValues(
                              alpha: .08,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(icons[i], size: 22),
                            title: Text(
                              labels[i],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => setState(() {
                              tab = i;
                              query = '';
                              category = 'All tools';
                              favoritesOnly = false;
                            }),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: brandPurple.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: brandPurple),
                            SizedBox(height: 10),
                            Text(
                              'Your files. Your control.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Local tools keep your documents on your device.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Profile'),
                        onTap: openProfile,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  GlassSurface(
                    radius: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 36 : 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          if (!wide)
                            const Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Brand(),
                              ),
                            )
                          else
                            Text(
                              labels[tab],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Spacer(),
                          if (wide)
                            const Text(
                              'A little less paperwork.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(width: 16),
                          IconButton(
                            tooltip: 'Profile',
                            onPressed: openProfile,
                            icon: CircleAvatar(
                              radius: 17,
                              backgroundColor: Color(0xFFEDE2FF),
                              child: Text(
                                SupabaseBackend.active?.profile?.initial ?? 'S',
                                style: const TextStyle(
                                  color: brandPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: tab == 2
                        ? Padding(
                            padding: EdgeInsets.only(bottom: wide ? 0 : 100),
                            child: ScannerScreen(store: widget.store),
                          )
                        : tab == 3
                        ? Padding(
                            padding: EdgeInsets.only(bottom: wide ? 0 : 100),
                            child: filesView(),
                          )
                        : toolsView(wide),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GlassSurface(
                radius: 30,
                blur: true,
                child: GlassMenu(
                  selectedIndex: tab,
                  labels: labels,
                  icons: icons,
                  onSelected: (i) => setState(() {
                    tab = i;
                    query = '';
                    category = 'All tools';
                    favoritesOnly = false;
                  }),
                ),
              ),
            ),
    );
  }

  Widget toolsView(bool wide) {
    final images = tab == 1;
    final contentWidth =
        (MediaQuery.sizeOf(context).width - (wide ? 226 + 64 : 32)).clamp(
          1.0,
          1160.0,
        );
    final columns = contentWidth >= 900
        ? 6
        : contentWidth >= 600
        ? 4
        : contentWidth >= 280
        ? 3
        : 2;
    final tileWidth = ((contentWidth - (columns - 1) * 12) / columns).clamp(
      1.0,
      1160.0,
    );
    final selected = tools
        .where(
          (t) =>
              t.image == images &&
              (category == 'All tools' || t.category == category) &&
              (!favoritesOnly || widget.store.favorites.contains(t.id)) &&
              '${t.name} ${t.description}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final groups = images
        ? ['Image tools']
        : [
            'Convert to PDF',
            'Convert from PDF',
            'Organize',
            'Optimize',
            'Edit & enhance',
            'Security',
          ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 16,
        wide ? 32 : 16,
        wide ? 32 : 16,
        wide ? 32 : 112,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!images)
                HomeHeroCarousel(
                  width: contentWidth,
                  onCreatePdf: () =>
                      openTool(tools.firstWhere((t) => t.id == 'image_pdf')),
                  onEnhance: () => openTool(imageEnhanceTool),
                ),
              if (images) ...[
                WorkspaceBanner(
                  images: true,
                  compact: true,
                  availableWidth: contentWidth,
                  heading: 'Enhance your\nphotos',
                  eyebrow: 'AUTO ENHANCEMENT',
                  caption:
                      'Brighter color. Clearer contrast.\nEnhanced on your device.',
                  actionLabel: 'Enhance a photo',
                  assetPath: 'assets/tool_icons_3d/image_enhance.png',
                  onStart: () => openTool(imageEnhanceTool),
                ),
              ],
              const SizedBox(height: 22),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: images ? 'Search tools' : 'Search tools',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              if (selected.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No tools found. Try a different search.'),
                ),
              for (final group in groups)
                if (selected.any((t) => t.category == group)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    child: Text(
                      group,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 18,
                    children: selected
                        .where((t) => t.category == group)
                        .map(
                          (t) => SizedBox(width: tileWidth, child: toolCard(t)),
                        )
                        .toList(),
                  ),
                ],
              if (widget.store.files.isNotEmpty) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent files',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => tab = 3),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                ...widget.store.files.take(3).map(fileTile),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget toolCard(DocTool tool) => Column(
    children: [
      GlassCard(
        margin: EdgeInsets.zero,
        child: Stack(
          children: [
            Tooltip(
              message:
                  '${tool.description} ${tool.available
                      ? tool.local
                            ? 'On your device'
                            : 'Processing service'
                      : 'Planned feature'}',
              child: InkWell(
                onTap: () => openTool(tool),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: Center(child: ToolGlyph(tool: tool)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Favorite ${tool.name}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => widget.store.toggleTool(tool.id),
                icon: Icon(
                  widget.store.favorites.contains(tool.id)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 15,
                  color: widget.store.favorites.contains(tool.id)
                      ? brandPurple
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: .45),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 9),
      InkWell(
        onTap: () => openTool(tool),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            tool.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ),
      if (!tool.available)
        Text(
          'Planned',
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
    ],
  );

  Widget filesView() {
    final items = widget.store.files
        .where(
          (f) =>
              f.name.toLowerCase().contains(query.toLowerCase()) &&
              (!favoritesOnly || f.favorite),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AccountPanel(store: widget.store),
        const SizedBox(height: 22),
        const Text(
          'Your files, all together.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Completed files are saved here automatically. Tap a file to view it or download a copy.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 22),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search saved files',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text('Favorites'),
            selected: favoritesOnly,
            onSelected: (v) => setState(() => favoritesOnly = v),
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Column(
              children: [
                Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 18),
                Text(
                  'A fresh start for your documents.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Your completed documents and scans will appear here.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ...items.map(fileTile),
      ],
    );
  }

  Widget fileTile(DocFile f) => GlassCard(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: brandPurple.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          f.extension == 'pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.insert_drive_file_outlined,
          color: brandPurple,
        ),
      ),
      title: Text(
        f.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${fileSize(f.bytes.length)}  â€¢  ${f.tool}  â€¢  ${f.created.day}/${f.created.month}/${f.created.year}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(file: f, store: widget.store),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'download') {
            try {
              await FilePicker.platform.saveFile(
                fileName: f.name,
                bytes: f.bytes,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(cleanError(e))));
              }
            }
          }
          if (action == 'favorite') {
            f.favorite = !f.favorite;
            await widget.store.persist();
          }
          if (action == 'delete') {
            await widget.store.remove(f);
          }
          if (action == 'rename' && mounted) {
            final controller = TextEditingController(text: f.name);
            final name = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Rename file'),
                content: TextField(controller: controller),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            controller.dispose();
            if (name != null && name.trim().isNotEmpty) {
              f.name = name.trim().replaceAll(RegExp(r'[/\\]'), '_');
              await widget.store.persist();
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'favorite',
            child: Text(f.favorite ? 'Remove favorite' : 'Favorite'),
          ),
          const PopupMenuItem(value: 'download', child: Text('Download')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete from history'),
          ),
        ],
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/branding/super_docs_symbol.png',
          width: 42,
          height: 42,
          semanticLabel: 'SUPER - Docs logo',
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'SUPER',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 23,
          letterSpacing: -1,
        ),
      ),
      const Text(' - Docs', style: TextStyle(fontSize: 23, letterSpacing: -1)),
    ],
  );
}

class MiniLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const MiniLabel(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: brandPurple),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF7C817F)),
      ),
    ],
  );
}
