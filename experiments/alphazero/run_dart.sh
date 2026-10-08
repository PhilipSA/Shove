#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH="${FLUTTER_HOME:-$HOME/develop/flutter}/bin:$PATH"
case "${1:-help}" in
  export)
    shift
    exec .venv-alphazero/bin/python experiments/alphazero/export_dart.py "$@"
    ;;
  test)
    shift
    exec dart experiments/alphazero/test_dart_runner.dart "$@"
    ;;
  build)
    mkdir -p .dart_tool
    exec dart compile exe experiments/alphazero/dart_runner.dart -o .dart_tool/alphazero_dart_runner
    ;;
  run)
    shift
    exec dart experiments/alphazero/dart_runner.dart "$@"
    ;;
  *)
    echo 'Usage: run_dart.sh {export <checkpoint> <new-dir> [--reference]|test <weights.json> <reference.json>|build|run <weights.json> [simulations] [milliseconds]}'
    ;;
esac
