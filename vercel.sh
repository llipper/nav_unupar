#!/bin/bash

set -e

echo "=== Instalando Flutter ==="

git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  -b stable \
  "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

echo "=== Versão do Flutter ==="
flutter --version

echo "=== Habilitando Flutter Web ==="
flutter config --enable-web

echo "=== Instalando dependências ==="
flutter pub get

echo "=== Gerando aplicação Web ==="
flutter build web --release

echo "=== Build concluído ==="