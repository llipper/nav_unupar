// lib/utils/constants.dart
//
// Constantes globais do aplicativo.
// Centralizadas aqui para facilitar manutenção e configuração.

class AppConstants {
  AppConstants._(); // Classe não instanciável

  // ===== PORTAL =====

  /// URL inicial do portal universitário.
  /// ATENÇÃO: Substitua pela URL real do seu portal.
  static const String portalUrl = 'https://www.google.com.br';

  /// Título exibido na tela inicial
  static const String appTitle = 'Portal Universitário';

  // ===== USER-AGENT =====

  /// User-Agent que simula o Chrome 138 no Windows Desktop.
  /// Isso faz o servidor retornar o arquivo com o Content-Type correto
  /// (application/vnd.openxmlformats-officedocument.wordprocessingml.document)
  /// em vez de application/xml ou text/xml, que é o que acontece com UA mobile.
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/138.0.0.0 Safari/537.36';

  /// User-Agent mobile (para comparação / fallback)
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/138.0.6834.79 Mobile Safari/537.36';

  // ===== ARMAZENAMENTO =====

  /// Nome da pasta dentro de Documents onde os arquivos são salvos
  static const String downloadFolderName = 'Universidade';

  /// Chave do SharedPreferences para o histórico de downloads
  static const String historyStorageKey = 'download_history';

  // ===== DOWNLOAD =====

  /// Timeout da conexão em segundos
  static const int connectionTimeoutSeconds = 30;

  /// Timeout do recebimento de dados em segundos
  static const int receiveTimeoutSeconds = 120;

  /// Número máximo de redirecionamentos HTTP a seguir
  static const int maxRedirects = 10;

  // ===== EXTENSÕES CORRIGÍVEIS =====

  /// Extensões que o servidor costuma enviar incorretamente
  /// e que precisam ser detectadas por magic bytes
  static const List<String> suspectExtensions = [
    'xml', 'bin', 'dat', 'tmp', 'download', ''
  ];

  // ===== CONTENT-TYPES PROBLEMÁTICOS =====

  /// Content-Types que o servidor frequentemente usa incorretamente
  /// para arquivos Word
  static const List<String> xmlContentTypes = [
    'application/xml',
    'text/xml',
    'application/octet-stream',
    'application/zip', // DOCX é um ZIP, mas deve ser renomeado
  ];
}
