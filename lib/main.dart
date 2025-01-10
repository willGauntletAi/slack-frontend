import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'providers/auth_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/channel_provider.dart';
import 'providers/message_provider.dart';
import 'providers/websocket_provider.dart';
import 'providers/typing_indicator_provider.dart';
import 'providers/workspace_users_provider.dart';
import 'providers/presence_provider.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WebSocketProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => ChannelProvider(
            context.read<WebSocketProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceUsersProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => TypingIndicatorProvider(
            context.read<WebSocketProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MessageProvider(
            context.read<ChannelProvider>(),
            context.read<AuthProvider>(),
            context.read<WebSocketProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PresenceProvider(
            context.read<WebSocketProvider>(),
          ),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slack Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasAttemptedConnection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    // Only attempt to connect once when authenticated
    if (!_hasAttemptedConnection &&
        authProvider.isAuthenticated &&
        authProvider.accessToken != null) {
      _hasAttemptedConnection = true;
      wsProvider.connect(authProvider.accessToken!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      return const HomePage();
    }

    return const LoginPage();
  }
}
