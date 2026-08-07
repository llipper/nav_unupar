// lib/widgets/error_snackbar.dart
//
// Helper para exibir mensagens de feedback padronizadas (erro, sucesso, aviso).

import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  AppSnackBar._();

  /// Exibe um SnackBar estilizado com o tipo especificado.
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message,
      type: SnackBarType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: SnackBarType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message, type: SnackBarType.warning);
  }

  static _SnackBarConfig _getConfig(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return const _SnackBarConfig(
          icon: Icons.check_circle_rounded,
          backgroundColor: Color(0xFF1B5E20),
        );
      case SnackBarType.error:
        return const _SnackBarConfig(
          icon: Icons.error_rounded,
          backgroundColor: Color(0xFFB71C1C),
        );
      case SnackBarType.warning:
        return const _SnackBarConfig(
          icon: Icons.warning_rounded,
          backgroundColor: Color(0xFFE65100),
        );
      case SnackBarType.info:
        return const _SnackBarConfig(
          icon: Icons.info_rounded,
          backgroundColor: Color(0xFF0D47A1),
        );
    }
  }
}

class _SnackBarConfig {
  final IconData icon;
  final Color backgroundColor;

  const _SnackBarConfig({
    required this.icon,
    required this.backgroundColor,
  });
}
