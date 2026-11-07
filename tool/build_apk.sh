#!/usr/bin/env bash
# Compila la APK con las conexiones de config/entornos.json incluidas,
# para que la app abra lista para usar sin configurar nada en el móvil.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="config/entornos.json"
if [[ ! -f "$CONFIG" ]]; then
  cp config/entornos.example.json "$CONFIG"
  echo "Creado $CONFIG a partir del ejemplo. Rellénalo y vuelve a ejecutar." >&2
  exit 1
fi

python3 -c "import json,sys; json.load(open('$CONFIG'))" || { echo "$CONFIG no es JSON válido" >&2; exit 1; }

flutter build apk --release --dart-define-from-file="$CONFIG" "$@"
echo
echo "APK lista: build/app/outputs/flutter-apk/app-release.apk"
