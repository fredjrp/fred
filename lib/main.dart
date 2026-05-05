// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/local_storage_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/auth/auth_screen.dart';
import 'ui/screens/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait+landscape on mobile, unrestricted on desktop
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialise Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialise Hive (registers adapters + opens boxes)
  await LocalStorageService.init();

  // Open box references after initialisation
  await LocalStorageService().openBoxes();

  runApp(const LoyversePosApp());
}

class LoyversePosApp extends StatelessWidget {
  const LoyversePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Connectivity — must come first so other providers can observe it
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider()..init(),
        ),

        // Auth — initialises Firebase auth listener
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),

        // Inventory — loads local data on creation
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(),
        ),

        // Cart — pure in-memory state
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),

        // Customers
        ChangeNotifierProvider(
          create: (_) => CustomerProvider(),
        ),

        // Transactions
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'LoyversePOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AppRouter(),
      ),
    );
  }
}

/// Listens to auth state and routes between AuthScreen and AppShell.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    // Give Firebase auth a tick to emit its initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _initialised = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      return const _SplashScreen();
    }

    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const _SplashScreen();
    }

    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    // Trigger a background sync after auth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = auth.storeId;
      if (storeId.isNotEmpty) {
        context.read<InventoryProvider>().loadFromLocal().then((_) {
          context.read<InventoryProvider>().syncFromFirebase(storeId);
        });
        context.read<CustomerProvider>().loadFromLocal().then((_) {
          context.read<CustomerProvider>().syncFromFirebase(storeId);
        });
        context.read<TransactionProvider>().loadFromLocal();
      }
    });

    return const AppShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.point_of_sale,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LoyversePOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Point of Sale System',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
