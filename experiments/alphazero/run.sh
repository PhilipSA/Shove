#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="${FLUTTER_HOME:-$HOME/develop/flutter}/bin:$PATH"
python=.venv-alphazero/bin/python
build() {
  mkdir -p .dart_tool
  dart compile exe experiments/alphazero/engine.dart -o .dart_tool/alphazero_engine
}
case "${1:-help}" in
  setup)
    if [[ ! -d .venv-alphazero ]]; then uv venv --python 3.12 .venv-alphazero; fi
    uv pip install --python "$python" -r experiments/alphazero/requirements.txt
    flutter pub get
    ;;
  test)
    build
    "$python" -m unittest discover -s experiments/alphazero -p 'test_*.py'
    ;;
  train|audit|compare|fit|loop|diagnose)
    command="$1"
    shift
    build
    exec "$python" "experiments/alphazero/$command.py" "$@"
    ;;
  help)
    echo 'Usage: bash experiments/alphazero/run.sh {setup|test|train [options]|audit <run-directory>|compare [options]|fit [options]|loop [options]|diagnose [options]}'
    echo 'Separate native experiment only: no app, worker, baseline or match-runner changes.'
    ;;
  *) echo "Unknown command: $1" >&2; exit 2 ;;
esac
