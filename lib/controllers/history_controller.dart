// lib/controllers/history_controller.dart
//
// Controller do histórico de downloads (ChangeNotifier para uso com Provider).
// Gerencia carregamento, exclusão e abertura de arquivos do histórico (suporta web e nativo).

import 'dart:io' show File;

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

  List<DownloadRecord> _records = [];
  List<DownloadRecord> get records => List.unmodifiable(_records);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => _records.isEmpty;
  int get count => _records.length;

  int get totalSize => _records.fold<int>(0, (sum, r) => sum + r.fileSize);

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

  void addRecord(DownloadRecord record) {
    _records.insert(0, record);
    notifyListeners();
  }

  Future<bool> deleteRecord(String id, {bool deleteFile = true}) async {
    final record = _records.where((r) => r.id == id).firstOrNull;
    if (record == null) return false;

    if (deleteFile && !kIsWeb) {
      try {
        final file = File(record.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await _repository.deleteRecord(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();

    return true;
  }

  Future<void> clearAll({bool deleteFiles = false}) async {
    if (deleteFiles && !kIsWeb) {
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

  Future<OpenResult> openFile(DownloadRecord record) async {
    if (kIsWeb) {
      return OpenResult(
        type: ResultType.done,
        message: 'Arquivo baixado via navegador.',
      );
    }

    final file = File(record.filePath);
    if (!await file.exists()) {
      return OpenResult(
        type: ResultType.noAppToOpen,
        message: 'Arquivo não encontrado no dispositivo.',
      );
    }

    var result = await OpenFilex.open(record.filePath, type: record.mimeType);

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

  Future<void> shareFile(DownloadRecord record) async {
    if (kIsWeb) return;

    final file = File(record.filePath);
    if (!await file.exists()) return;

    await Share.shareXFiles(
      [XFile(record.filePath, mimeType: record.mimeType)],
      subject: record.fileName,
    );
  }

  Future<bool> fileExists(DownloadRecord record) async {
    if (kIsWeb) return true;
    return File(record.filePath).exists();
  }
}

