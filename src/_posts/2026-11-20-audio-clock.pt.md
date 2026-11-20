---
layout: post
title: Sincronizando o vídeo com o relógio do áudio entre threads
locale: pt
slug: audio-clock
date: 2026-11-20
tags: [video, audio, testing]
---

Quando vídeo e áudio discordam durante a reprodução, um dos dois tem que
ceder. No [editor](https://viniciuscole.com/lab/editor/), quem cede é sempre o
vídeo. Um quadro perdido quase ninguém nota. Um buraco ou um estalo no áudio,
todo mundo nota. Então o `AudioContext` é o relógio mestre, e a imagem segue
ele.

Seria simples se os dois morassem no mesmo lugar. Não moram. O
`AudioContext` só existe na thread principal, e os quadros de vídeo são
decodificados e desenhados num worker de renderização (a
[visão geral](/pt/2026/11/20/how-it-works/) explica por quê). Este post é
sobre manter duas threads no mesmo passo, e sobre um áudio que tem que soar
igual no preview e no [arquivo exportado](/pt/2026/11/20/export/).

## Áudio sem streaming

O áudio de cada asset é decodificado uma vez com `decodeAudioData` e fica na
memória como um `AudioBuffer`. A reprodução agenda um `AudioBufferSourceNode`
por clipe audível, passando por um nó de ganho do clipe e outro da trilha. Num
seek ou numa edição durante a reprodução, os nós agendados param e são
agendados de novo a partir do tempo atual.

Isso custa memória: a spec estima uns 230 MB para dez minutos de estéreo a
48 kHz. A alternativa, decodificar em pedaços com `AudioDecoder` e alimentar
um `AudioWorklet` por buffers circulares, está na lista do que ficou fora do
escopo. Nada no editor compartilha memória entre threads, então não existe
`SharedArrayBuffer`. O editor não precisa dos cabeçalhos de isolamento entre
origens (COOP e COEP), e o deploy não põe nenhum.

## Âncoras

A thread principal não transmite o relógio para o worker. Ela manda âncoras:
no play, em todo seek e a cada 250 ms ela posta `{ timeUs, wallMs, rate }`,
que quer dizer "neste instante no relógio da página, a timeline está neste
tempo e andando nesta taxa". O worker extrapola entre as âncoras e desenha o
quadro correspondente.

O tempo do áudio vem de `AudioContext.getOutputTimestamp()`. Ele junta o
tempo do contexto da amostra que está saindo no alto-falante agora com o
`performance.now()` do mesmo instante, então a latência de saída já entra na
conta. Antes de existir um timestamp, ele cai para
`currentTime − outputLatency − baseLatency`.

Duas coisas entraram durante os testes. O dispositivo de áudio às vezes
começava mais tarde que o previsto, então a thread principal também confere a
cada 20 ms e posta uma âncora nova quando o relógio do áudio se afastou mais
de 4 ms da última. E uma âncora pode ter data no futuro: "a timeline começa a
andar em `wallMs`". O worker segura o primeiro quadro até a primeira amostra
poder ser ouvida, em vez de sair na frente dela.

## O `now` de quem?

Uma âncora tem um tempo no relógio da página, e o worker precisa converter
para o dele. O `performance.now()` de um worker conta a partir de uma origem
diferente da página.

A primeira versão estimava a diferença como o menor atraso de mensagem que
tinha visto. Com o worker ocupado decodificando, essa estimativa começava
dezenas de milissegundos alta demais, e nos primeiros segundos o vídeo ficava
cerca de um quadro atrás do relógio. A ideia seguinte foi o
`performance.timeOrigin`. O Chrome deriva ele do relógio de parede, e no WSL
um worker criado mais tarde na vida da página saía uns 2 segundos errado.

O que funciona é medir. O worker responde um pedido de `now` na hora, fora da
fila de trabalho dele. O editor tira cinco amostras quando abre e mais uma a
cada play, e fica com a de menor ida e volta.

## Medindo o descompasso

Os testes precisam de um número para "em sincronia". Toda vez que o worker
desenha um quadro durante a reprodução, ele anota a hora do desenho. A thread
principal então pergunta ao relógio do áudio qual quadro estava tocando
naquele instante e guarda a diferença. Os testes afirmam que a maior diferença
numa reprodução inteira fica em um quadro ou menos, e que pelo menos 80% dos
quadros foram conferidos.

O revisor apontou um limite dessa medida. A hora do desenho é convertida de
volta para o tempo da página com a mesma diferença que o worker usou, então um
erro nessa diferença se cancela e não aparece. O erro é no máximo metade da
melhor ida e volta, abaixo de um milissegundo com o worker ocioso. Isso ficou
registrado como pendência em vez de escondido.

Nos testes, o Chrome sobe com `--autoplay-policy=no-user-gesture-required`,
então o `AudioContext` de verdade roda e os testes passam pelo caminho de
áudio de produção. No app, o contexto começa suspenso e o primeiro Play
retoma ele.

## Play, pause, play

Esse `resume()` rendeu os dois bugs de que eu mais gosto nesta parte.

O primeiro: no app, o `resume()` pode levar até 500 ms. Aperte Play, Pause,
Play antes de ele terminar, e o áudio do primeiro play começa mesmo assim
quando ele termina. Cada play tinha o próprio relógio de áudio, e o primeiro
agendava a voz dele depois de já ter sido parado. Duas cópias do áudio
tocavam, fora de passo, e o Pause só parava uma. Bastava um toque duplo na
barra de espaço. O teste simula um `resume()` lento e conta as vozes.

A correção disso fez um play atropelado parar o relógio que ele tinha
iniciado. Só que, sem áudio, todos os plays dividem um relógio de parede só.
Um play velho parava o relógio em que o play novo estava rodando, e a agulha
congelava com o botão de Pause na tela. O revisor pegou isso com a mesma
sequência Play, Pause, Play num clipe sem som, e o teste escrito para o caso
falha no código antigo com:

```
expected 0 to be greater than 15
```

Agora um play só para um relógio compartilhado quando nenhum play mais novo
está usando. A primeira rodada de correções já tinha dado a cada parada um
fade de 5 ms, porque cortar um som no meio da onda estala.

## Muitas trilhas, um plano

Várias trilhas de áudio vieram depois: mudo por trilha, volume por clipe (0 a
200%) e fades de entrada e saída. O fade é linear no ganho:
`volume × min(1, (t − start) / fadeIn, (end − t) / fadeOut)`. O mudo leva o
ganho da trilha com uma constante de tempo de 2 ms, para também não estalar.

A decisão importante é que nada disso é uma mudança ao vivo no grafo da
reprodução. Volume, fades e mudo são campos de um plano (uma entrada por voz,
com o ganho da trilha e a curva de ganho), e a mesma função agenda esse plano
para a reprodução, para a renderização offline de onde os testes leem
amostras e para os pedaços de 10 segundos da exportação. Quando uma mixagem
começa no meio de um fade, como pode acontecer na emenda entre dois pedaços
da exportação, a curva é cortada no início da voz para começar no ganho certo.

O revisor testou isso com oito mutações, e cada uma derrubou algum teste.
Mixar a segunda trilha no preview e não na exportação derrubou 4 testes. Um
fade de potência constante no lugar do linear derrubou os testes da curva. Um
fade um quadro longo demais passou do limite de 2e-3 por um fio, com
2,31e-3, e uma segunda afirmação pegou com mais folga.

Não tem limitador. Duas trilhas altas, ou um clipe a 200%, podem passar de
1,0 e saturar, mas saturam igual no preview e no arquivo. Clipes com
velocidade diferente de 1× ficam mudos, como a spec permite por enquanto.

Como preview e exportação rodam o mesmo plano, "a exportação soa igual ao
preview" vale por construção. O que os testes precisam conferir é o plano, e
isso era uma coisa bem menor para acertar.
