// lib/pages/history_page.dart
//
// Tela de histórico de downloads.
// Lista todos os arquivos baixados com opções de abrir, compartilhar e excluir.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../controllers/history_controller.dart';
import '../models/download_record.dart';
import '../utils/file_utils.dart';
import '../widgets/error_snackbar.dart';
import '../widgets/history_tile.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Recarregar histórico ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryController>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            _buildHeader(context),

            // ===== CONTEÚDO =====
            Expanded(
              child: Consumer<HistoryController>(
                builder: (_, ctrl, __) {
                  if (ctrl.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A73E8),
                      ),
                    );
                  }

                  if (ctrl.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildHistoryList(context, ctrl);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<HistoryController>(
      builder: (_, ctrl, __) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          border: Border(
            bottom: BorderSide(color: Colors.white12, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Botão voltar
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Histórico de Downloads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),

                // Botão limpar tudo
                if (!ctrl.isEmpty)
                  IconButton(
                    onPressed: () => _confirmClearAll(context, ctrl),
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.white38,
                    ),
                    tooltip: 'Limpar tudo',
                  ),
              ],
            ),

            // Estatísticas
            if (!ctrl.isEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.insert_drive_file_rounded,
                      label: '${ctrl.count} arquivo${ctrl.count != 1 ? 's' : ''}',
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.data_usage_rounded,
                      label: FileUtils.formatFileSize(ctrl.totalSize),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white38),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum download ainda',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Os arquivos baixados pelo portal\naparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, HistoryController ctrl) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: ctrl.records.length,
      itemBuilder: (context, index) {
        final record = ctrl.records[index];

        return FutureBuilder<bool>(
          future: ctrl.fileExists(record),
          builder: (context, snapshot) {
            final exists = snapshot.data ?? true;

            return HistoryTile(
              record: record,
              fileExists: exists,
              onOpen: exists
                  ? () => _openFile(context, ctrl, record)
                  : null,
              onShare: exists
                  ? () => ctrl.shareFile(record)
                  : null,
              onDelete: () => _confirmDelete(context, ctrl, record),
            );
          },
        );
      },
    );
  }

  Future<void> _openFile(
    BuildContext context,
    HistoryController ctrl,
    DownloadRecord record,
  ) async {
    final result = await ctrl.openFile(record);

    if (!context.mounted) return;

    switch (result.type) {
      case ResultType.done:
        break; // Sucesso, nada a fazer
      case ResultType.noAppToOpen:
        AppSnackBar.showWarning(
          context,
          'Nenhum aplicativo encontrado para abrir arquivos .${record.fileType}. '
          'Instale o Microsoft Office ou WPS Office.',
        );
      case ResultType.fileNotFound:
        AppSnackBar.showError(context, 'Arquivo não encontrado no dispositivo.');
      case ResultType.permissionDenied:
        AppSnackBar.showError(
          context,
          'Permissão negada para abrir o arquivo.',
        );
      case ResultType.error:
        AppSnackBar.showError(
          context,
          result.message ?? 'Erro ao abrir o arquivo.',
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HistoryController ctrl,
    DownloadRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2530),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir arquivo?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja excluir "${record.fileName}"?\n\nEsta ação também removerá o arquivo do dispositivo.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ctrl.deleteRecord(record.id, deleteFile: true);
      if (context.mounted) {
        if (success) {
          AppSnackBar.showSuccess(context, 'Arquivo excluído com sucesso.');
        } else {
          AppSnackBar.showError(context, 'Não foi possível excluir o arquivo.');
        }
      }
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    HistoryController ctrl,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2530),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Limpar histórico?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja remover todos os ${ctrl.count} registros do histórico?\n\nOs arquivos físicos também serão excluídos.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Limpar tudo',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ctrl.clearAll(deleteFiles: true);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Histórico limpo com sucesso.');
      }
    }
  }
}
