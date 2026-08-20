#!/bin/sh
# Monta o jogo e empacota o bundle .jsdos.
#   /src  = fonte do tic-tac-toe-assembly (somente leitura)
#   /conf = dosbox.conf
#   /out  = onde o vca.jsdos e gravado
set -e

echo "montando o assembly..."
nasm -f obj /src/vca.asm -o /tmp/vca.obj
nasm -f obj /src/draw.asm -o /tmp/draw.obj

echo "ligando o executavel DOS..."
cd /tmp
/opt/ow/binl64/wlink format dos file /tmp/vca.obj,/tmp/draw.obj name /tmp/VCA.EXE

echo "empacotando o bundle..."
rm -rf /tmp/bundle
mkdir -p /tmp/bundle/.jsdos
cp /tmp/VCA.EXE /tmp/bundle/VCA.EXE
cp /conf/dosbox.conf /tmp/bundle/.jsdos/dosbox.conf

cd /tmp/bundle
rm -f /out/vca.jsdos
zip -r -X /out/vca.jsdos VCA.EXE .jsdos

echo "pronto:"
ls -l /out/vca.jsdos
