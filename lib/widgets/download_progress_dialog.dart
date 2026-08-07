// lib/widgets/download_progress_dialog.dart
//
// Dialog exibido durante o download de um arquivo.
// Mostra progresso, nome do arquivo e opção de cancelar.

import 'package:flutter/material.dart';
import '../utils/file_utils.dart';

class DownloadProgressDialog extends StatelessWidget {
  /// Nome do arquivo sendo baixado
  final String fileName;

  /// Bytes baixados até agora
  final int downloadedBytes;

  /// Total de bytes (-1 se desconhecido)
  final int totalBytes;

  /// Callback ao pressionar "Cancelar"
  final VoidCallback? onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.fileName,
    required this.downloadedBytes,
    required this.totalBytes,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalBytes > 0 ? downloadedBytes / totalBytes : null;
    final progressPercent =
        progress != null ? '${(progress * 100).toStringAsFixed(0)}%' : '...';

    return PopScope(
      // Impedir fechar com botão voltar durante o download
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E2530),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone animado de download
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 32,
                color: Color(0xFF4FC3F7),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              'Baixando arquivo',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Nome do arquivo (truncado se longo)
            Text(
              fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Barra de progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4FC3F7),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Texto de progresso
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  FileUtils.formatFileSize(downloadedBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                Text(
                  progressPercent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4FC3F7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalBytes > 0
                      ? FileUtils.formatFileSize(totalBytes)
                      : 'Calculando...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botão cancelar
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
