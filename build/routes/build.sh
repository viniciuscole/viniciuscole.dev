#!/bin/bash
set -euo pipefail
cd /src

if [ "$(git rev-parse HEAD)" != "$SHA_ESPERADO" ]; then
  echo "ERRO: /src esta em $(git rev-parse HEAD), esperado $SHA_ESPERADO" >&2
  exit 1
fi

emcc -std=gnu99 -Os \
  src/PQ.c src/adjacency.c src/algorithm.c src/edge.c src/updates.c src/util.c src/route.c src/trace.c \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=criarRotas \
  -sEXPORTED_FUNCTIONS='["_run_trace"]' \
  -sEXPORTED_RUNTIME_METHODS='["ccall"]' \
  -sALLOW_MEMORY_GROWTH=0 \
  -sEXIT_RUNTIME=0 \
  -o /out/rotas.js

ls -l /out/
