# Suporte Web e Implantação na Vercel — Portal Universitário & DOCX Repair

## Contexto

O aplicativo mobile Android (`navegador_docx`) está funcional. Agora precisamos ajustar o projeto para que ele funcione perfeitamente como um **site / aplicativo web** e seja **implantável na Vercel** sem erros.

Atualmente, o código contém dependências diretas de `dart:io` e plugins móveis (`open_filex`, `permission_handler`, `path_provider`) que impedem a compilação e execução na Web / Vercel.

---

## O que será feito

1. **Compatibilidade Web (Flutter Web Cross-Platform)**:
   - Adicionar verificações `kIsWeb` e abstração de armazenamento/downloads para funcionar nativamente no navegador (download via Blob/anchor HTML na Web, sem crash de `dart:io`).
   - Tratar `InAppWebView` e fallback web responsivo no browser.
   - Tornar `HistoryController`, `DownloadService`, `HistoryPage` e `main.dart` 100% seguros para Web.

2. **Ferramenta Web Online de Correção DOCX**:
   - Integrar na interface Web um utilitário de reparo online onde o usuário pode arrastar e soltar arquivos XML/DOCX corrompidos recebidos do portal para correção automática de extensão/magic bytes diretamente no navegador.

3. **Configuração Vercel (`vercel.json` e `package.json`)**:
   - Criar `vercel.json` com regras de reescrita SPA (`/ -> index.html`), cabeçalhos CORS e MIME types corretos (`.wasm`, `.json`, `.docx`).
   - Criar `package.json` com scripts de build e exportação web.
   - Garantir que o site carregue instantaneamente na Vercel.

---

## Alterações Propostas

### 1. Raiz do Projeto (Vercel Configuration)

#### [NEW] [vercel.json](file:///c:/Users/Ignotus/Desktop/navegador_docx/vercel.json)
- Configuração de rotas SPA (Single Page Application rewrite).
- MIME types para WebAssembly, JSON e arquivos DOCX/XML.
- Cabeçalhos de segurança e cache estático.

#### [NEW] [package.json](file:///c:/Users/Ignotus/Desktop/navegador_docx/package.json)
- Script de build Vercel (`"build": "flutter build web --release"` / exportação estática).

---

### 2. Dart / Flutter (Adaptação para Web)

#### [MODIFY] [main.dart](file:///c:/Users/Ignotus/Desktop/navegador_docx/lib/main.dart)
- Guardar `Platform.isAndroid` com `!kIsWeb` para não lançar exceção em navegadores.

#### [MODIFY] [download_service.dart](file:///c:/Users/Ignotus/Desktop/navegador_docx/lib/services/download_service.dart)
- Adicionar suporte a download no navegador web via Blob / AnchorElement quando `kIsWeb` for verdadeiro.
- Evitar chamadas a `path_provider` e `File` do `dart:io` no ambiente web.

#### [MODIFY] [history_controller.dart](file:///c:/Users/Ignotus/Desktop/navegador_docx/lib/controllers/history_controller.dart)
- Adaptar abertura e compartilhamento de arquivos na Web (download direto ou preview).
- Evitar `open_filex` e `share_plus` no contexto Web quando não suportados.

#### [MODIFY] [browser_page.dart](file:///c:/Users/Ignotus/Desktop/navegador_docx/lib/pages/browser_page.dart)
- Adicionar visualização responsiva Web para desktop/mobile e fallback para navegação no portal no ambiente Web.

---

### 3. Web Assets (`web/`)

#### [MODIFY] [index.html](file:///c:/Users/Ignotus/Desktop/navegador_docx/web/index.html)
- Atualizar meta tags SEO, favicon, viewport responsivo e inicialização do Flutter Web.
- Adicionar suporte a drag-and-drop e estilo escuro premium.

---

## Plano de Verificação

### Testes de Compilação
- Executar validação da estrutura web e garantir ausência de erros de `dart:io` na compilação web.

### Verificação Vercel
- Confirmar integridade de `vercel.json` e `package.json`.
- Garantir suporte a roteamento de página única e MIME types na Vercel.
