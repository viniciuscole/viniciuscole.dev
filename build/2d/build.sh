#!/bin/bash
# Aplica os patches do site sobre o fonte do trabalho e compila para
# WebAssembly. Roda dentro do container; /src e o clone, /patches sao os
# patches, /out recebe os artefatos.
set -euo pipefail

cd /src

# Diretorio de patches vazio nao e estado legitimo desta receita: sem o
# 0001 o jogo aborta no primeiro quadro com "unsupported immediate mode 9"
# (GL_POLYGON nao existe na emulacao de modo imediato do Emscripten). Falha
# aqui, alto e com mensagem clara, em vez de deixar o git apply quebrar
# depois com um criptico "No such file or directory" quando o glob
# /patches/*.patch nao casa com nada.
patches=(/patches/*.patch)
if [ ! -e "${patches[0]}" ]; then
  echo "ERRO: nenhum .patch em /patches. A receita nunca constroi sem patches --" >&2
  echo "sem o 0001 o jogo aborta no primeiro quadro com 'unsupported immediate mode 9'." >&2
  exit 1
fi

for patch in "${patches[@]}"; do
  echo "== aplicando $(basename "$patch")"
  # Sem --check antes: `git apply` ja falha inteiro ou nao aplica nada, e o
  # set -e derruba a build. Seguir sem o patch produziria um .wasm que aborta
  # no primeiro circulo desenhado.
  git apply --verbose "$patch"
done

# em++, nao emcc: o projeto e C++ e o emcc falha nos simbolos da stdlib.
# LEGACY_GL_EMULATION cobre o OpenGL em modo imediato (glBegin/glVertex2f).
# MODULARIZE evita que o modulo suba sozinho ao carregar o script, que e o
# que permite carregar a demo so no clique.
#
# --js-library glut-text-stubs.js: o Emscripten declara glRasterPos2f,
# glutBitmapCharacter e glutBitmapHelvetica18 nos headers de GL/GLUT mas nunca
# implementa nenhuma das tres -- sem o shim o link falha com "undefined
# symbol" antes de chegar ao navegador. Ver comentario no proprio arquivo.
#
# ANDAIME TEMPORARIO: quando uma tarefa posterior deste plano remover do C++
# as chamadas a essas tres funcoes, apague junto o arquivo glut-text-stubs.js
# e esta flag. Mantido depois disso, uma reintroducao futura de texto do
# GLUT linkaria em silencio sem desenhar nada -- o erro de link e o unico
# sinal de que essa API nao existe no Emscripten.
em++ -std=c++11 -O2 \
  main.cpp arena.cpp tinyxml2.cpp character.cpp hero.cpp enemy.cpp shot.cpp \
  -sLEGACY_GL_EMULATION=1 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sEXIT_RUNTIME=0 \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=criarJogo2D \
  -lGL -lglut \
  --js-library /patches/glut-text-stubs.js \
  --preload-file arena_teste.svg \
  -o /out/jogo.js

ls -l /out/
