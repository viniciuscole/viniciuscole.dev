---
layout: post
title: Portando assembly de DOS para o navegador
locale: pt
slug: porting-dos-assembly-to-the-browser
date: 2026-08-16
---

Meu jogo da velha é escrito em assembly x86 de 16 bits, em modo real. Não existe
compilador que transforme isso em WebAssembly — o conjunto de instruções, o
modelo de memória segmentada e as interrupções do DOS não têm alvo equivalente.

Então o plano é emulação: montar o código original com o NASM, linkar num
executável DOS e rodar esse executável dentro do DOSBox compilado para
WebAssembly. O WebAssembly aqui é o emulador, não o meu código, e eu acho que
essa honestidade importa mais do que o rótulo.

O build já funciona: o `nasm -f obj` monta os dois arquivos-fonte sem uma única
mudança, e o linker do Open Watcom produz um executável DOS de 3.244 bytes.
