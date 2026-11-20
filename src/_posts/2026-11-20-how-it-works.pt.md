---
layout: post
title: Como funciona o editor de vídeo no navegador
locale: pt
slug: how-it-works
date: 2026-11-20 00:00:40 -03:00
tags: [video, webcodecs, agents]
---

O [editor de vídeo](https://viniciuscole.com/lab/editor/) deste site é um
editor multipista e não destrutivo que roda inteiro no navegador. Você importa
clipes, corta e apara na timeline, empilha trilhas, põe texto e crossfades e
exporta um MP4. Nada é enviado para servidor nenhum. Os arquivos são copiados
para o armazenamento privado do navegador (OPFS) e ficam na sua máquina.

Este post é o mapa. Outros quatro entram nas partes que deram trabalho:

- [Seek com precisão de quadro no WebCodecs](/pt/2026/11/20/frame-accurate-seeking/)
- [Edição na timeline com desfazer e refazer](/pt/2026/11/20/timeline-editing/)
- [Exportando vídeo no navegador sem servidor](/pt/2026/11/20/export/)
- [Sincronizando o vídeo com o relógio do áudio entre threads](/pt/2026/11/20/audio-clock/)

## Três threads

A thread principal roda a interface, guarda o documento do projeto e é dona
do grafo de áudio, porque o `AudioContext` não existe em workers. Ela nunca
encosta num quadro de vídeo.

Um worker de renderização cuida de tudo que é visual: os decoders, o cache de
quadros, o código que descobre qual clipe está sob a agulha e o compositor que
desenha num `OffscreenCanvas`. A exportação sobe workers próprios e reaproveita
o mesmo resolvedor e o mesmo compositor, avançando quadro a quadro em vez de
seguir um relógio.

O Mediabunny lê e escreve os contêineres: faz o demux de MP4 e WebM, levanta
os metadados, monta o índice de keyframes e faz o mux da exportação. Tudo
depois disso, a decodificação, o seek e o cache de quadros, foi escrito à mão
em cima do WebCodecs. A spec chama essa parte de núcleo do projeto, então ela
não vem de biblioteca.

## O tempo é um inteiro

Todo tempo no documento é um número inteiro de microssegundos, a mesma unidade
dos timestamps do WebCodecs. Todo ponto de edição cai num quadro do projeto, e
o quadro `n` fica em `round(n · 1e6 · den / num)`. A 29,97 fps (30000/1001), o
quadro 1 é 33.367 µs e o quadro 30 é exatamente 1.001.000 µs. Reprodução, seek
e exportação andam por índices de quadro e nunca somam microssegundos, então
nada escorrega.

## Edições são patches

Toda mudança no projeto é um comando com nome. O Immer gera um patch de ida e
um de volta para cada um, o desfazer e o refazer reaplicam esses patches, e os
mesmos patches vão para o worker de renderização, que mantém a própria cópia
do documento. O projeto inteiro nunca é reenviado depois de uma edição. Os
testes de propriedade conferem que a cópia do worker e a da thread principal
continuam iguais depois de cada passo aleatório.

## Uma porta só para os testes

O editor inteiro fica atrás de uma classe `Editor` sem interface. A UI é um
cliente fino dela, e ela é a única coisa que os testes podem tocar. Eles
importam arquivos, disparam comandos, fazem seek e dão play, e então conferem
o que sai: o documento, os pixels de um quadro renderizado, amostras de
áudio, os bytes de um MP4 exportado. Nenhum teste mexe no pool de decoders, no
cache ou no compositor, então essas peças podem mudar sem encostar em teste.

Pixel só serve para conferir alguma coisa se você sabe qual pixel esperar. Os clipes de
teste têm um contador queimado em cada quadro, uma cor de fundo que muda a
cada segundo e uma faixa de 8 bits com o número do quadro. Um helper lê a
faixa de volta de um screenshot. Cada clipe existe em H.264/AAC e em VP9/Opus,
e os testes rodam no Google Chrome de marca, porque o Chromium que vem com o
Playwright não traz H.264 nem AAC.

## Canvas2D primeiro, depois WebGPU

O compositor é uma interface com duas implementações. O Canvas2D veio primeiro
e cobre tudo: camadas, picture-in-picture, opacidade, texto, crossfades. O
WebGPU chegou por último e tem que produzir os mesmos quadros. Os testes
comparam a saída dele com os quadros de referência do Canvas2D.

Os quadros de vídeo entram no WebGPU com `importExternalTexture`, sem cópia.
Depois o resultado é copiado para um canvas 2D uma vez por quadro, então o
caminho não é zero-copy de ponta a ponta. Essa cópia mantém a leitura de
pixels e o fallback para Canvas2D funcionando num alvo só. No modo `auto` o
editor recusa um adaptador WebGPU por software, porque WebGPU em software é
mais lento que Canvas2D.

A perda de device precisou de uma proteção própria. Entre o momento em que um device
de GPU morre e o momento em que `device.lost` resolve, um desenho devolve um
quadro preto e não lança nada. No preview, é um quadro ruim. Numa exportação,
que roda mais rápido que o tempo real, são vários quadros pretos gravados no
arquivo. Hoje cada lane da exportação confere se o device sobreviveu ao quadro
e, se não sobreviveu, desenha de novo no Canvas2D. Sem essa checagem, o teste
falha com `exported frame 13 is black`.

O CI não tem GPU, então os testes de WebGPU rodam no SwiftShader, uma
implementação em software. A primeira configuração que funcionou gastava uns
110 segundos de um timeout de 120, cerca de 6× mais lento que localmente,
e o revisor recusou até os timeouts ganharem folga. O primeiro
efeito, uma correção de cor escrita em WGSL, entrou com o último ticket da
spec. No Canvas2D, os clipes saem sem os efeitos e o painel de exportação avisa.

## Quem escreveu

A maior parte do código foi escrita por agentes de IA, e o jeito como eles
foram organizados explica muito do que está aí em cima.

A spec é uma issue do GitHub. Ela foi quebrada em 24 tickets, ligados por
dependências de "blocked by". Um agente orquestrador acha os tickets cujos
bloqueios já fecharam, no máximo três por vez, e sobe um agente implementador
para cada um, na sua própria worktree do git. O implementador trabalha com
teste primeiro, pela classe `Editor`, abre um PR em rascunho e anexa
evidência: o resultado dos testes ligado a cada critério de aceite e, quando
algo visível mudou, screenshots anotados e um vídeo. Depois um agente revisor
separado, que não pode editar o código, revisa o PR. Depois de duas rodadas
de correção, ticket que ainda tem problema vem para mim. Só eu faço merge.

As revisões saem da minha própria conta, então o GitHub recusa "approve" e
"request changes" nelas. O veredito vai na primeira linha do comentário.

A regra que tornou as revisões úteis está nas instruções do revisor: um teste
que passaria com a funcionalidade removida é um achado. Então o revisor
quebra o código de propósito, roda a suíte e relata o que sobreviveu. Dos 23
PRs que fecharam um ticket, 22 voltaram com mudanças pedidas na primeira
rodada.

O primeiríssimo PR teve um desses. O teste de "o primeiro quadro aparece no
preview" lia os pixels do canvas interno do próprio compositor. O revisor
apontou que ele continuaria passando se a chamada que entrega o canvas
visível ao worker não fizesse nada. O usuário veria um preview vazio, com a
suíte verde. A correção foi tirar screenshot do elemento que o usuário vê de
fato, e os testes de preview seguintes copiaram esse padrão.

O PR dos crossfades teve um mais discreto. Um crossfade usa material além do
corte, de depois do ponto de saída do clipe que sai e de antes do ponto de
entrada do clipe que entra. O revisor trocou esses quadros de sobra por cópias
congeladas do último e do primeiro quadro, e os 21 testes de crossfade
continuaram passando: no clipe de teste, os quadros de sobra tinham por acaso
a mesma cor dos congelados.

Nem tudo está resolvido. Alguns testes medem reprodução em tempo real a 4K, e
eles falham quando a máquina está ocupada. Estão marcados como instáveis
conhecidos nos PRs, não corrigidos.

O esquema inteiro se apoia na regra do revisor: teste que continua passando
com a funcionalidade removida é bug no teste.
