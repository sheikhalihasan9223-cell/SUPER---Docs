import 'package:flutter/material.dart';
import 'main.dart';
import 'store.dart';

class StartupApp extends StatefulWidget {
  final Future<AppStore> Function() load;
  const StartupApp({super.key, required this.load});
  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late Future<AppStore> workspace = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<AppStore>(
    future: workspace,
    builder: (context, snapshot) {
      if (snapshot.hasData) return AliDocsApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 340,
                        maxHeight: 340,
                      ),
                      child: Image.asset(
                        'assets/branding/super_docs_logo.png',
                        fit: BoxFit.contain,
                        semanticLabel:
                            'SUPER - Docs. All solution in one place.',
                      ),
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Could not start your workspace. Please try again.',
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => workspace = widget.load()),
                        child: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
