import 'package:flutter/material.dart';

import 'camera_view/camera_screen.dart';
import 'monitor_view/monitor_screen.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AetherLinkApp());
}

class AetherLinkApp extends StatelessWidget {
  const AetherLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AetherLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const _HomeScreen(),
        AppRoutes.camera: (_) => const CameraScreen(),
        AppRoutes.monitor: (_) => const MonitorScreen(),
      },
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AetherLink')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.camera),
              child: const Text('Start as Camera'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.monitor),
              child: const Text('Start as Monitor'),
            ),
          ],
        ),
      ),
    );
  }
}
