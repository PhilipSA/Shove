#!/usr/bin/env bash
# Rebuilds BOTH browser workers from source, then (for build-web) the Flutter web app,
# so neither the Squadron MinMax worker nor the AlphaZero worker can be stale.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${FLUTTER_HOME:-$HOME/develop/flutter}/bin:$PATH"

workers() {
  flutter pub get
  # Regenerates the Squadron service/worker glue for the MinMax evaluator.
  dart run build_runner build --delete-conflicting-outputs
  dart compile js -O4 \
    lib/game_objects/game_state/shove_game_evaluator_service.web.g.dart \
    -o web/shove_game_evaluator_service.web.g.dart.js
  dart compile js -O4 \
    lib/ai/alpha_zero/alpha_zero_worker_main.dart \
    -o web/alpha_zero_worker.js
}

case "${1:-help}" in
  workers) workers ;;
  build-web)
    workers
    flutter build web --release --no-pub
    ;;
  *)
    echo "Usage: bash tool/alpha_zero_web.sh workers|build-web" >&2
    exit 1
    ;;
esac
