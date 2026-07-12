import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/transactions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseConfig = SupabaseConfig.fromEnvironment();
  await Supabase.initialize(
    url: supabaseConfig.normalizedUrl,
    publishableKey: supabaseConfig.normalizedAnonKey,
  );

  runApp(const MyApp());
}

final _routerProvider = Provider.family<GoRouter, String>((
  ref,
  initialLocation,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  final routerRefresh = ref.watch(_routerRefreshProvider);

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute = path == '/sign-in' || path.startsWith('/sign-up');
      final isProtectedRoute = path == '/dashboard' || path == '/transactions';

      if (!authRepository.isSignedIn && isProtectedRoute) {
        return '/sign-in';
      }

      if (authRepository.isSignedIn && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) =>
            const SignUpScreen(intendedRole: AuthIntendedRole.owner),
      ),
      GoRoute(
        path: '/sign-up/owner',
        builder: (context, state) =>
            const SignUpScreen(intendedRole: AuthIntendedRole.owner),
      ),
      GoRoute(
        path: '/sign-up/boarder',
        builder: (context, state) =>
            const SignUpScreen(intendedRole: AuthIntendedRole.boarder),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});

final _routerRefreshProvider = Provider<_AuthRouterRefresh>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refresh = _AuthRouterRefresh(authRepository.authStateChanges);

  ref.onDispose(refresh.dispose);

  return refresh;
});

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Stream<AuthUserSnapshot?> authStateChanges) {
    _subscription = authStateChanges.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthUserSnapshot?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _ApartmentApp(initialLocation: initialLocation),
    );
  }
}

class _ApartmentApp extends ConsumerWidget {
  const _ApartmentApp({required this.initialLocation});

  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider(initialLocation));

    return MaterialApp.router(
      title: 'Apartment Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: _LandingContent(colorScheme: colorScheme),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandingContent extends StatelessWidget {
  const _LandingContent({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Apartment Manager',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Track dues, proof uploads, and payment history.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        const RoleCardsLayout(),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: const Key('landing-owner-sign-up-button'),
              onPressed: () => context.go('/sign-up/owner'),
              child: const Text('Create owner account'),
            ),
            FilledButton.tonal(
              key: const Key('landing-boarder-sign-up-button'),
              onPressed: () => context.go('/sign-up/boarder'),
              child: const Text('Create boarder account'),
            ),
            OutlinedButton(
              key: const Key('landing-sign-in-button'),
              onPressed: () => context.go('/sign-in'),
              child: const Text('Sign in'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Boarders create an account first, then join with the owner invite code.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class RoleCardsLayout extends StatelessWidget {
  const RoleCardsLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final useWideLayout = MediaQuery.sizeOf(context).width >= 720;
    const ownerCard = RoleCard(
      title: 'Owner',
      description: 'Create dues, review proofs, and monitor balances.',
      icon: Icons.apartment,
    );
    const boarderCard = RoleCard(
      title: 'Boarder',
      description: 'View dues, submit proof, and check payment history.',
      icon: Icons.person_outline,
    );

    if (useWideLayout) {
      return const Row(
        children: [
          Expanded(child: ownerCard),
          SizedBox(width: 16),
          Expanded(child: boarderCard),
        ],
      );
    }

    return const Column(
      children: [ownerCard, SizedBox(height: 16), boarderCard],
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
