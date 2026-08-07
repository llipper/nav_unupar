# Portal Universitário — Navegador com Correção de Downloads DOCX

## Contexto

O projeto Flutter já existe (`navegador_docx`) mas contém apenas o código padrão de template. Precisamos substituí-lo por um aplicativo completo com WebView, interceptação de downloads e correção do tipo de arquivo.

O problema: portais universitários enviam documentos Word com `Content-Type: application/xml` ou `text/xml`, fazendo o Android salvar como `.xml` em vez de `.docx`. A solução é interceptar o download, analisar os magic bytes do arquivo e renomear corretamente.

---

## Estrutura de Arquivos

```
lib/
├── main.dart
├── app/
│   ├── app.dart                   # MaterialApp + tema
│   └── routes.dart                # Rotas nomeadas
├── models/
│   └── download_record.dart       # Modelo do histórico
├── services/
│   ├── download_service.dart      # Lógica de download com Dio
│   ├── file_type_service.dart     # Detecção de tipo por magic bytes
│   └── storage_service.dart       # Persistência do histórico (SharedPreferences)
├── repositories/
│   └── download_repository.dart   # Abstração entre service e controller
├── controllers/
│   ├── webview_controller.dart    # Estado da WebView (ChangeNotifier)
│   └── history_controller.dart   # Estado do histórico
├── pages/
│   ├── home_page.dart             # Tela inicial com botão "Acessar Portal"
│   ├── browser_page.dart          # WebView + barra de progresso
│   └── history_page.dart         # Lista de downloads
└── widgets/
    ├── download_progress_dialog.dart  # Dialog de progresso
    ├── history_tile.dart              # Item da lista de histórico
    └── error_snackbar.dart            # Mensagens de erro padronizadas
```

---

## Dependências a Adicionar

| Pacote | Versão | Uso |
|---|---|---|
| `flutter_inappwebview` | ^6.1.5 | WebView com interceptação de downloads |
| `dio` | ^5.7.0 | Download com headers customizados |
| `path_provider` | ^2.1.4 | Localizar diretório Documents |
| `open_filex` | ^4.6.0 | Abrir arquivos salvos |
| `permission_handler` | ^11.3.1 | Permissão de armazenamento |
| `share_plus` | ^10.0.0 | Compartilhar arquivos |
| `shared_preferences` | ^2.3.2 | Persistir histórico de downloads |
| `intl` | ^0.19.0 | Formatação de data/hora |
| `provider` | ^6.1.2 | Gerenciamento de estado |

---

## Proposed Changes

### Android — Configurações Nativas

#### [MODIFY] [AndroidManifest.xml](file:///c:/Users/Ignotus/Desktop/navegador_docx/android/app/src/main/AndroidManifest.xml)
- Adicionar permissões: `INTERNET`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_DOCUMENTS`
- Adicionar `FileProvider` para compartilhamento de arquivos (Android 10+)
- Adicionar `android:usesCleartextTraffic="true"` para compatibilidade
- Configurar `queries` para intent de abertura de documentos

#### [NEW] `android/app/src/main/res/xml/file_paths.xml`
- Configuração do FileProvider para compartilhar arquivos da pasta Documents

#### [MODIFY] [build.gradle.kts](file:///c:/Users/Ignotus/Desktop/navegador_docx/android/app/build.gradle.kts)
- Definir `minSdk = 29` (Android 10)
- Definir `targetSdk = 35`

---

### pubspec.yaml

#### [MODIFY] [pubspec.yaml](file:///c:/Users/Ignotus/Desktop/navegador_docx/pubspec.yaml)
- Adicionar todas as dependências listadas acima
- Atualizar `description` e metadados do app

---

### Dart — Camada de Modelos

#### [NEW] `lib/models/download_record.dart`
- Campos: `id`, `fileName`, `filePath`, `fileType`, `fileSize`, `downloadedAt`, `url`
- Métodos: `toJson()`, `fromJson()`, serialização para SharedPreferences

---

### Dart — Serviços

#### [NEW] `lib/services/file_type_service.dart`
- Mapa de magic bytes: DOCX (`PK\x03\x04`), PDF (`%PDF`), ZIP, PNG, JPEG
- Mapa de Content-Type → extensão
- Método `detectExtension(Uint8List bytes, String? contentType, String? contentDisposition, String? url) → String`
- Prioridade: magic bytes > Content-Disposition > Content-Type > URL

#### [NEW] `lib/services/download_service.dart`
- Configuração do Dio com User-Agent desktop Chrome/138
- Método `downloadFile(url, cookies)` com progresso via stream
- Cabeçalhos: `Cookie`, `User-Agent`, `Accept`, `Referer`
- Criação automática da pasta `Documents/Universidade/`
- Retorna `DownloadRecord` com metadados

#### [NEW] `lib/services/storage_service.dart`
- Persistência do histórico em SharedPreferences como JSON
- CRUD: `saveRecord`, `getAll`, `deleteRecord`, `clearAll`

---

### Dart — Repositórios

#### [NEW] `lib/repositories/download_repository.dart`
- Orquestra `DownloadService` + `StorageService`
- Método `performDownload(url, cookies, onProgress)` → `DownloadRecord`
- Tratamento de erros com mensagens localizadas

---

### Dart — Controllers

#### [NEW] `lib/controllers/webview_controller.dart`
- `ChangeNotifier` com: `isLoading`, `progress`, `currentUrl`, `title`
- Referência à instância do `InAppWebViewController`
- Método `handleDownload(url, cookies)`

#### [NEW] `lib/controllers/history_controller.dart`
- `ChangeNotifier` com lista de `DownloadRecord`
- Métodos: `loadHistory`, `deleteRecord`, `addRecord`

---

### Dart — Páginas

#### [NEW] `lib/pages/home_page.dart`
- Design premium: gradiente azul escuro/índigo, glassmorphism
- Logo/ícone animado da universidade
- Botão "Acessar Portal" com animação
- Versão do app e informações no rodapé

#### [NEW] `lib/pages/browser_page.dart`
- `InAppWebView` com User-Agent desktop
- Barra superior com: voltar, avançar, recarregar, URL atual, botão histórico
- Barra de progresso de carregamento da página
- Interceptação via `onDownloadStartRequest` + `shouldOverrideUrlLoading`
- Dialog de progresso durante download
- Snackbar de sucesso/erro após download

#### [NEW] `lib/pages/history_page.dart`
- Lista de downloads com `HistoryTile`
- Cabeçalho com total de arquivos e tamanho acumulado
- Ações por item: Abrir, Compartilhar, Excluir
- Estado vazio com ilustração

---

### Dart — Widgets

#### [NEW] `lib/widgets/download_progress_dialog.dart`
- Dialog com LinearProgressIndicator animado
- Nome do arquivo, velocidade de download, bytes baixados
- Botão cancelar

#### [NEW] `lib/widgets/history_tile.dart`
- Ícone por tipo de arquivo (DOCX, PDF, ZIP…)
- Nome, tamanho, data/hora formatados
- Menu de contexto com 3 ações

#### [NEW] `lib/widgets/error_snackbar.dart`
- Helper estático `show(context, message, type)`
- Tipos: error, warning, success

---

### Dart — Utilitários

#### [NEW] `lib/utils/constants.dart`
- User-Agent desktop
- URL do portal (configurável)
- Nome da pasta de download

#### [NEW] `lib/utils/file_utils.dart`
- Formatação de tamanho (bytes → KB/MB/GB)
- Formatação de data/hora

---

### Ponto de entrada

#### [MODIFY] `lib/main.dart`
- Inicializar `WidgetsFlutterBinding`, permissões e `Provider`

#### [NEW] `lib/app/app.dart`
- `MaterialApp` com tema escuro premium (azul índigo + dourado)
- Rotas definidas

---

## Design System

- **Fonte**: Google Fonts (Outfit/Inter via CDN não disponível → usar sistema)  
- **Paleta**: Fundo `#0D1117`, Primário `#1A73E8` (azul Google), Accent `#4FC3F7`, Superfície `#161B22`
- **Estilo**: Glassmorphism nas cards, gradientes suaves, bordas arredondadas `16px`
- **Animações**: Fade-in na home, slide na navegação, progress animado

---

## Lógica Central — Detecção de DOCX

```
1. Usuário clica em download na WebView
2. onDownloadStartRequest intercepta URL + cookies
3. Dio faz GET com cookies + User-Agent desktop
4. Primeiros 4 bytes lidos: PK\x03\x04 = arquivo ZIP (base do DOCX)
5. Se ZIP: verificar se contém "[Content_Types].xml" (magic DOCX)
6. Content-Disposition: filename="*.docx" → confirma DOCX
7. Salvar como .docx em Documents/Universidade/
8. Registrar no histórico
9. Notificar usuário com snackbar + opção "Abrir"
```

---

## Verificação

### Build
```bash
flutter pub get
flutter build apk --debug
```

### Checklist Manual
- [ ] Abrir portal na WebView
- [ ] Fazer login mantém sessão (cookies)
- [ ] Clicar em download Word → arquivo salvo como .docx
- [ ] Histórico exibe o arquivo
- [ ] Abrir arquivo abre Microsoft Word / WPS
- [ ] Compartilhar envia via WhatsApp/e-mail

> [!IMPORTANT]
> **URL do Portal**: O código usará `https://www.google.com.br` como placeholder. Após aprovação, informe a URL real do portal da sua universidade para substituirmos no `constants.dart`.

> [!NOTE]
> **Permissões Android 13+**: Em Android 13+, `READ_EXTERNAL_STORAGE` foi substituído por `READ_MEDIA_DOCUMENTS`. O app solicitará as permissões corretas para cada versão do SDK automaticamente.
