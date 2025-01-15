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
import 'providers/search_provider.dart';
import 'providers/ask_ai_provider.dart';
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
          create: (context) => WebSocketProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            authService: authService,
            wsProvider: context.read<WebSocketProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(),
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
            authProvider: context.read<AuthProvider>(),
            wsProvider: context.read<WebSocketProvider>(),
            channelProvider: context.read<ChannelProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PresenceProvider(
            context.read<WebSocketProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AskAiProvider(),
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
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show loading screen while checking auth status
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If authenticated and we have user data, show home page
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      return const HomePage();
    }

    // Otherwise show login page
    return const LoginPage();
  }
}
