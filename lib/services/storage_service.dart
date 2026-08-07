// lib/services/storage_service.dart
//
// Serviço de persistência do histórico de downloads.
// Usa SharedPreferences para salvar os registros como JSON.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_record.dart';
import '../utils/constants.dart';

class StorageService {
  /// Salva um novo registro de download no histórico.
  /// O novo registro é adicionado ao topo da lista.
  Future<void> saveRecord(DownloadRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAll();

    // Adicionar novo registro no início (mais recente primeiro)
    records.insert(0, record);

    // Serializar e salvar
    final jsonList = records.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(AppConstants.historyStorageKey, jsonList);
  }

  /// Retorna todos os registros de download, mais recentes primeiro.
  Future<List<DownloadRecord>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          prefs.getStringList(AppConstants.historyStorageKey) ?? [];

      return jsonList
          .map((jsonStr) {
            try {
              return DownloadRecord.fromJson(
                jsonDecode(jsonStr) as Map<String, dynamic>,
              );
            } catch (_) {
              // Ignorar registros corrompidos
              return null;
            }
          })
          .whereType<DownloadRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove um registro específico pelo ID.
  Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAll();

    // Filtrar removendo o registro com o ID especificado
    final updated = records.where((r) => r.id != id).toList();

    final jsonList = updated.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(AppConstants.historyStorageKey, jsonList);
  }

  /// Remove todos os registros do histórico.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.historyStorageKey);
  }

  /// Retorna o número de registros no histórico.
  Future<int> getCount() async {
    final records = await getAll();
    return records.length;
  }

  /// Retorna o tamanho total acumulado de todos os downloads em bytes.
  Future<int> getTotalSize() async {
    final records = await getAll();
    return records.fold<int>(0, (sum, r) => sum + r.fileSize);
  }
}
