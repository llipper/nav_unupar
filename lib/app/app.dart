// lib/app/app.dart
//
// Configuração raiz do MaterialApp com tema premium escuro.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/history_controller.dart';
import '../controllers/webview_controller.dart';
import 'routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Configurar aparência da status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0D1117),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MultiProvider(
      providers: [
        // Controller da WebView (um por sessão de navegação)
        ChangeNotifierProvider<WebViewController>(
          create: (_) => WebViewController(),
        ),
        // Controller do histórico de downloads
        ChangeNotifierProvider<HistoryController>(
          create: (_) => HistoryController(),
        ),
      ],
      child: MaterialApp(
        title: 'Portal Universitário',
        debugShowCheckedModeBanner: false,

        // ===== TEMA ESCURO PREMIUM =====
        theme: _buildTheme(),

        // ===== ROTAS =====
        initialRoute: AppRoutes.home,
        routes: appRoutes,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Paleta de cores principal
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1A73E8),       // Azul Google
        onPrimary: Colors.white,
        secondary: Color(0xFF4FC3F7),     // Azul claro
        onSecondary: Colors.black,
        surface: Color(0xFF161B22),       // Surface escuro
        onSurface: Colors.white,
        error: Color(0xFFCF6679),
        outline: Color(0xFF30363D),
      ),

      // Cor de fundo de todos os Scaffolds
      scaffoldBackgroundColor: const Color(0xFF0D1117),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Botões elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),

      // Botões de contorno
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
      ),

      // Diálogos
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E2530),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white60,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // Tipografia
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 15),
        bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
        bodySmall: TextStyle(color: Colors.white54, fontSize: 12),
      ),

      // Ícones
      iconTheme: const IconThemeData(color: Colors.white70),

      // Divisores
      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 0.5,
      ),
    );
  }
}
