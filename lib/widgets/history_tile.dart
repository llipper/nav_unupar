// lib/widgets/history_tile.dart
//
// Item da lista de histórico de downloads.
// Exibe nome, tipo, tamanho, data e ações (Abrir, Compartilhar, Excluir).

import 'package:flutter/material.dart';
import '../models/download_record.dart';
import '../utils/file_utils.dart';

class HistoryTile extends StatelessWidget {
  final DownloadRecord record;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool fileExists;

  const HistoryTile({
    super.key,
    required this.record,
    this.onOpen,
    this.onShare,
    this.onDelete,
    this.fileExists = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = Color(
      int.parse(
        FileUtils.colorForFileType(record.fileType).replaceFirst('#', '0xFF'),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2232),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fileExists ? Colors.white.withOpacity(0.06) : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: fileExists ? onOpen : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ===== ÍCONE DO TIPO =====
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: typeColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        record.typeIcon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // ===== INFORMAÇÕES =====
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome do arquivo
                      Text(
                        record.fileName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fileExists ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Tipo e tamanho
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.fileType.toUpperCase(),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            FileUtils.formatFileSize(record.fileSize),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Data e hora
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: Colors.white30,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            FileUtils.formatRelativeDate(record.downloadedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      // Aviso se arquivo não existe mais
                      if (!fileExists) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              size: 11,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Arquivo não encontrado',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ===== MENU DE AÇÕES =====
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'open':
                        onOpen?.call();
                      case 'share':
                        onShare?.call();
                      case 'delete':
                        onDelete?.call();
                    }
                  },
                  color: const Color(0xFF1E2A3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white38,
                  ),
                  itemBuilder: (_) => [
                    if (fileExists)
                      PopupMenuItem(
                        value: 'open',
                        child: _buildMenuItem(
                          icon: Icons.open_in_new_rounded,
                          label: 'Abrir',
                          color: const Color(0xFF4FC3F7),
                        ),
                      ),
                    if (fileExists)
                      PopupMenuItem(
                        value: 'share',
                        child: _buildMenuItem(
                          icon: Icons.share_rounded,
                          label: 'Compartilhar',
                          color: Colors.greenAccent,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _buildMenuItem(
                        icon: Icons.delete_rounded,
                        label: 'Excluir',
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}
