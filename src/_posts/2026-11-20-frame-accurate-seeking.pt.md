---
layout: post
title: Seek com precisão de quadro no WebCodecs
locale: pt
slug: frame-accurate-seeking
date: 2026-11-20
tags: [video, webcodecs, testing]
---

Um editor tem que mostrar o quadro exato que está sob a agulha. Se você corta
no quadro 118, o preview mostra o quadro 118, não algo perto dele. O
[editor](https://viniciuscole.com/lab/editor/) faz isso com WebCodecs, e o
WebCodecs entrega muito pouco: um `VideoDecoder` que recebe pedaços
codificados e devolve `VideoFrame`s. Achar os pedaços certos, decidir quais
quadros guardar e quando jogar fora fica por sua conta. Esta é a parte da
[arquitetura](/pt/2026/11/20/how-it-works/) que a spec chama de núcleo do
projeto.

## A receita

Um vídeo é uma sequência de keyframes, cada um seguido de quadros que só
fazem sentido em relação aos anteriores. Para mostrar o quadro `n`, o worker
de renderização procura o keyframe anterior num índice montado na importação,
reseta o decoder, alimenta ele a partir desse keyframe e descarta todo quadro
antes do alvo. Se o alvo fica mais adiante no mesmo grupo de quadros (GOP) em
que o decoder já está, ele segue sem reset, então avançar um quadro sai
barato.

Os clipes de teste deixam isso verificável. Cada quadro tem o número
queimado na imagem, uma cor de fundo que muda a cada segundo e uma faixa de
8 bits com o número do quadro. Os testes fazem o seek e leem a faixa de volta
dos pixels do preview. Um dos clipes roda a 29,97 fps com um keyframe só,
então o quadro 149 está a 149 quadros do seu keyframe.

Uma revisão logo no começo pegou que a faixa do quadro 0 é toda preta, então
um canvas vazio também lia como quadro 0. Agora o leitor não devolve nada se
o fundo não for uma das cores conhecidas do clipe.

## O quadro 0 não começa no zero

A primeira versão numerava os quadros pelo timestamp absoluto. O revisor
remuxou um clipe de teste com todos os pacotes deslocados em 0,1 s e
importou:

```
UndecodableMediaError: moved.webm couldn't be decoded: No decodable frame at frame 0
```

O primeiro quadro estava em 100 ms, então caiu no índice 3, e o índice 0 nunca
existiu. Não é arquivo exótico. Um MP4 com B-frames muxado sem edit list
começa uns quadros adiante, e remux de MPEG-TS também. A correção ancora a
grade de quadros no primeiro timestamp de apresentação da trilha, gravado na
importação. Clipes deslocados entraram para os fixtures de teste, nas duas
codificações.

## Seeks que chegam tarde demais

Seeks podem chegar mais rápido do que o decoder consegue terminar. Cada
pedido leva um número de geração, e o worker larga uma decodificação assim que
chega um mais novo.

A segunda rodada de revisão achou o único lugar sem checagem: logo depois do
flush no fim de um GOP, que é por onde passa todo seek para os últimos quadros
de um clipe. O revisor pôs um throw temporário para "um quadro voltou depois
que chegou um seek mais novo" e rodou uma varredura: seek para o último
quadro, espera de 0 a 40 ms, seek para o quadro 3. Disparou em três dos quatro
clipes de teste:

```
STALE_DRAW frame 119 gen 2 latest 3
STALE_DRAW frame 149 gen 2 latest 3
```

O preview piscava o quadro velho antes do certo. O teste que existia não via,
porque o quadro velho era desenhado primeiro e a ordem dos quadros continuava
parecendo certa. Hoje são duas checagens, uma depois do flush e outra na hora
de desenhar, e um contador de quadros desenhados depois que um seek mais novo
já tinha chegado. O teste afirma que ele fica em 0. Sem as duas checagens, ele
falha nos quatro clipes.

## Os quadros são do decoder

Um `VideoFrame` é uma referência para memória que pertence ao decoder. Segure
quadros demais e um decoder de hardware fica sem buffers de saída e para de
produzir quadros, sem erro nenhum. Por isso o cache é um LRU com orçamento em
bytes, e todo quadro que ele despeja é fechado explicitamente.

O orçamento é de 96 MB, dividido entre todos os clipes. Em 1080p, isso dá uns
30 quadros. Em 4K, uns 8. Durante a reprodução, saem primeiro os quadros que
ficaram para trás da agulha, depois o quadro mais distante à frente.

Uma espera pelo decoder ainda pode travar, então ela tem um timer de 2
segundos. A primeira versão armava o timer uma vez por flush, e um flush
saudável que levasse mais de 2 segundos numa máquina lenta contava como
travamento. A recuperação então limpava o cache, o que podia fechar o quadro
alvo, e caía no próximo quadro que tivesse. Quadro errado na tela, sem erro.
Agora o timer recomeça a cada quadro que sai, e depois de um travamento o alvo
é decodificado de novo a partir do keyframe, ou o pedido falha. Ele nunca
mostra outro quadro.

Os vazamentos também são contados. O worker acompanha cada quadro desde o
momento em que um decoder entrega até ele ser fechado. Depois de um merge, o
CI na `main` falhou com `expected 83 to be 82`: um quadro vivo fora do cache
depois de uma pausa. O decoder continua soltando quadros de pacotes que já
estavam na fila, mesmo depois que a tarefa que pediu foi embora. O último
deles caía num espaço reservado para fallback, e não sobrava ninguém para
fechar. Agora um quadro assim é fechado na chegada, a menos que alguma tarefa
ainda possa usar.

## Um decoder por clipe, quatro no total

Decoder de hardware é escasso, então o pool tem um limite rígido de 4. Cada
clipe sendo lido ganha o seu decoder, já que dois clipes do mesmo arquivo
precisam de duas posições nele. Quando bate no limite, o decoder ocioso usado
há mais tempo é resetado e passado adiante.

O scrub, arrastar a agulha, usa um modo mais barato. Enquanto você arrasta, o
preview mostra o keyframe mais próximo e um selinho `KEYFRAME`. Quando você
solta, ele faz o seek para o quadro exato. O keyframe é decodificado no decoder
do próprio clipe, então um arrasto nunca abre um segundo. A primeira versão
abria um segundo decoder para isso, e a revisão devolveu.

Esse reaproveitamento precisou de mais duas linhas: depois de decodificar um
keyframe sozinho, o clipe tem que esquecer em que ponto do GOP o decoder
estava. O revisor apagou as duas e os 115 testes continuaram passando. Aí ele
escreveu uma sequência de seek, scrub e soltar e teve 12 falhas em 16. O teste
que cobre isso hoje falha com o erro do próprio decoder:

```
DataError: ... A key frame is required after configure() or flush()
```

## Enquanto uma exportação roda

A exportação renderiza nos próprios workers e também precisa de decoders.
Quando ela começa, o preview cai para um decoder e mostra só keyframes, e as
lanes da exportação dividem os outros três, então o total nunca passa de 4. O
[post da exportação](/pt/2026/11/20/export/) conta o resto.

A maioria desses bugs apareceu porque um revisor foi atrás do momento ruim:
um clipe deslocado, um segundo seek 7 ms depois do primeiro, um scrub logo
depois de um seek no meio de um GOP. Os PRs de seek e de scrub levaram três
rodadas de revisão cada. Decodificar o quadro certo nunca foi o problema.
Garantir que nada além dele chegasse à tela foi.
