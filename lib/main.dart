import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'providers/auth_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/channel_provider.dart';
import 'providers/user_provider.dart';
import 'providers/message_provider.dart';
import 'providers/websocket_provider.dart';
import 'providers/typing_indicator_provider.dart';
import 'providers/dm_provider.dart';
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
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChannelProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WebSocketProvider(),
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
          create: (context) => DMProvider(
            context.read<AuthProvider>(),
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    // Connect to WebSocket when authenticated
    if (authProvider.isAuthenticated && authProvider.accessToken != null) {
      wsProvider.connect(authProvider.accessToken!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
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
      },
    );
  }
}
