#!/usr/bin/env bash
# Compila el Android App Bundle (.aab) firmado para subirlo a Google Play.
# Requisitos: config/entornos.json (conexiones) y android/key.properties + upload-keystore.jks (firma).
# Antes de cada nueva subida, sube el número tras el "+" en pubspec.yaml (version: 1.0.0+N).
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f config/entornos.json ]] || { echo "Falta config/entornos.json (copia config/entornos.example.json)" >&2; exit 1; }
[[ -f android/key.properties ]] || { echo "Falta android/key.properties (clave de subida)" >&2; exit 1; }

flutter build appbundle --release --dart-define-from-file=config/entornos.json "$@"

AAB=build/app/outputs/bundle/release/app-release.aab
echo
echo "Bundle listo: $AAB  (versión $(grep '^version:' pubspec.yaml | awk '{print $2}'))"
