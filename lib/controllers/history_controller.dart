// lib/controllers/history_controller.dart
//
// Controller do histórico de downloads (ChangeNotifier para uso com Provider).
// Gerencia carregamento, exclusão e abertura de arquivos do histórico.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/download_record.dart';
import '../repositories/download_repository.dart';

class HistoryController extends ChangeNotifier {
  final DownloadRepository _repository;

  HistoryController({DownloadRepository? repository})
    : _repository = repository ?? DownloadRepository();

  // ===== ESTADO =====

  List<DownloadRecord> _records = [];
  List<DownloadRecord> get records => List.unmodifiable(_records);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => _records.isEmpty;
  int get count => _records.length;

  /// Tamanho total de todos os arquivos em bytes
  int get totalSize => _records.fold<int>(0, (sum, r) => sum + r.fileSize);

  // ===== CARREGAMENTO =====

  /// Carrega o histórico do armazenamento
  Future<void> loadHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _records = await _repository.getHistory();
    } catch (e) {
      _errorMessage = 'Não foi possível carregar o histórico.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Adiciona um novo registro ao topo do histórico (sem recarregar do storage)
  void addRecord(DownloadRecord record) {
    _records.insert(0, record);
    notifyListeners();
  }

  // ===== EXCLUSÃO =====

  /// Exclui um registro do histórico e opcionalmente o arquivo físico
  Future<bool> deleteRecord(String id, {bool deleteFile = true}) async {
    final record = _records.where((r) => r.id == id).firstOrNull;
    if (record == null) return false;

    // Excluir arquivo físico se solicitado
    if (deleteFile) {
      try {
        final file = File(record.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Continuar mesmo se não conseguir excluir o arquivo
      }
    }

    // Remover do repositório
    await _repository.deleteRecord(id);

    // Remover da lista local
    _records.removeWhere((r) => r.id == id);
    notifyListeners();

    return true;
  }

  /// Limpa todo o histórico
  Future<void> clearAll({bool deleteFiles = false}) async {
    if (deleteFiles) {
      for (final record in _records) {
        try {
          final file = File(record.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }

    await _repository.clearHistory();
    _records.clear();
    notifyListeners();
  }

  // ===== ABRIR ARQUIVO =====

  /// Abre um arquivo com o aplicativo padrão do dispositivo
  Future<OpenResult> openFile(DownloadRecord record) async {
    final file = File(record.filePath);
    if (!await file.exists()) {
      return OpenResult(
        type: ResultType.noAppToOpen,
        message: 'Arquivo não encontrado no dispositivo.',
      );
    }

    // Tentar abrir via OpenFilex
    var result = await OpenFilex.open(record.filePath, type: record.mimeType);

    // Se der erro de permissão (comum no Android 11+ com arquivos fora do app storage),
    // copiar para o diretório temporário do app onde o FileProvider tem permissão total
    if (result.type == ResultType.permissionDenied) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${record.fileName}');
        await file.copy(tempFile.path);
        result = await OpenFilex.open(tempFile.path, type: record.mimeType);
      } catch (_) {}
    }

    return result;
  }

  // ===== COMPARTILHAR ARQUIVO =====

  /// Compartilha um arquivo via share sheet do Android
  Future<void> shareFile(DownloadRecord record) async {
    final file = File(record.filePath);
    if (!await file.exists()) return;

    await Share.shareXFiles(
      [XFile(record.filePath, mimeType: record.mimeType)],
      subject: record.fileName,
    );
  }

  // ===== VERIFICAR EXISTÊNCIA =====

  /// Verifica se o arquivo físico ainda existe no dispositivo
  Future<bool> fileExists(DownloadRecord record) async {
    return File(record.filePath).exists();
  }
}
