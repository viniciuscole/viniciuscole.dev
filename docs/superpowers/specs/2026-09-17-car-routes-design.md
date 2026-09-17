# Rotas com trânsito: Dijkstra replanejado, rodando na página

**Data:** 2026-09-17
**Status:** aprovado para planejamento
**Specs anteriores:**
`docs/superpowers/specs/2026-08-25-demo-2d-webassembly-design.md` (padrão de
build WASM em Docker com SHA fixo, que esta spec reaproveita)

## Objetivo

Publicar o [car-routes-optimazing](https://github.com/viniciuscole/car-routes-optimazing)
— trabalho de Técnicas de Busca e Ordenação (UFES, 2023), feito por Vinicius
Cole, João ([vortex2jm](https://github.com/vortex2jm)) e Gabriel Gatti
([gabrielgatti7](https://github.com/gabrielgatti7)) — como projeto do site,
com uma **página longa e didática sobre a otimização em si**, ilustrada por
**simulações visuais que rodam o C original compilado para WebAssembly**.

O leitor deve sair entendendo três coisas, vendo cada uma acontecer:

1. por que o peso da via é tempo, não distância;
2. como o Dijkstra com fila de prioridade encontra o caminho mais rápido;
3. o que o trabalho acrescenta: quando o trânsito muda no meio do trajeto, o
   carro replaneja **a partir de onde está**, e isso às vezes chega tarde.

## O problema que o C resolve

Entrada (um arquivo texto, `;` como separador):

```
N;E                      nós e arestas
origem;destino
velocidade               km/h, única, para todas as vias no instante 0
de;para;metros           × E   (arestas direcionadas)
instante;de;para;km/h    × qualquer quantidade (atualizações, em ordem de instante)
```

Peso da aresta = tempo = metros / (km/h ÷ 3,6). O programa:

1. roda Dijkstra (minimizando tempo) da origem ao destino;
2. anda pelo caminho nó a nó somando tempo e distância;
3. quando o relógio passa do instante da próxima atualização, aplica todas as
   atualizações vencidas (`update_adj` troca o tempo da aresta) e **roda
   Dijkstra de novo a partir do nó atual**;
4. repete até chegar. Saída: caminho, km, `hh:mm:ss`.

O código relevante: `algorithm.c` (`dijkstra`, `updateDistanceCallback`),
`PQ.c` (heap binário de mínimo), `main.c` (`calculate_path`, o loop de
replanejamento).

## O que já foi verificado na prática

Antes desta spec, com o repo clonado em `63a34a8`:

### Compila e roda nativo

`gcc -O2 src/*.c -lm` compila (só warnings de variável não usada). Cenário
de 6 nós / 9 arestas, origem 1, destino 6, 60 km/h, uma atualização em
t=30 s deixando a aresta 2→4 a 5 km/h:

| caso | caminho | km | tempo |
|---|---|---|---|
| com a atualização | `1;2;5;6` | 4,0 | `00:04:0.000000` |
| sem atualização | `1;2;4;6` | 3,0 | `00:02:60.000000` |

Os dois estão certos (conferidos à mão). O segundo expõe um **bug de
formatação**: 180 s vira `00:02:60` por erro de ponto flutuante em
`format_time` (`(int)total_time` cai para 179). Vai para o PR upstream.

### Compila e roda em WebAssembly

`emscripten/emsdk:6.0.8` (a mesma imagem do 2D), `emcc -O2` com todos os
`.c` inclusive `main.c`, `-sMODULARIZE=1 -sEXPORT_NAME=criarRotas
-sEXPORTED_RUNTIME_METHODS=callMain,FS`:

| artefato | bytes |
|---|---|
| `rotas.wasm` | 49.043 |
| `rotas.js` | 59.322 |

Rodado em Node 22 escrevendo o cenário no MEMFS e chamando `callMain`:
saída **byte a byte igual** à nativa, em 3 ms contando a inicialização do
módulo. Sem patch, sem flag especial: o C é ANSI puro com `stdio`.

## Decisões de arquitetura

### Motor: C original → WASM; JS só desenha

Descartadas: reimplementar o algoritmo em JS (o C viraria só um link) e
gerar traces offline (perderia o editor de trânsito). O que roda na página
**é o C do trabalho**, como nos outros projetos do site.

### Integração: trace em lote, não API passo a passo

O C ganha um modo que roda a simulação inteira e emite **um evento por
linha** no stdout. O JS captura tudo num array e o player só reproduz:
play/pause/passo/velocidade viram um índice. Grafos de 10–30 nós rodam em
microssegundos, então "editar e rodar de novo" é chamar a função outra vez.

Uma API passo a passo (`init/step/estado`) exigiria reescrever
`calculate_path` como máquina de estados e não traria nada para grafos
desse tamanho.

### Instrumentação vive no repo upstream, em branch própria

PR em `car-routes-optimazing` (branch `trace-mode`). O site fixa o SHA do
merge, como faz com o 2D — mas **sem patches**: tudo que o build precisa já
está no fonte. O projeto original melhora (README, bug de formatação, modo
trace) em vez de o site carregar um diff de 800 linhas de C.

### Interação: cenários prontos + player + editor de trânsito

Cada figura do texto é um player sobre um cenário fixo. O player principal
(topo da página) tem além disso um editor: clicar numa via abre instante e
nova velocidade; "Rodar" regenera a entrada e chama o C de novo.

### Formato: página de projeto longa, pt + en

Uma URL por idioma. O texto didático inteiro fica na página do projeto,
intercalado com os players; não há post separado.

## Seção 1 — Mudanças no `car-routes-optimazing`

Branch `trace-mode`, PR contra `main`. Nada do comportamento do CLI muda:
mesmo `trab2 entrada saida`, mesma saída (fora o bug de formatação).

### 1.1 Callbacks de instrumentação

Em `include/trace.h`, ponteiros de função globais, `NULL` por padrão:

```c
typedef struct {
  void (*pop)(int node, double time);                    /* nó fechado pelo Dijkstra  */
  void (*relax)(int from, int to, double new_time);      /* tempo de `to` melhorou     */
  void (*plan)(const int *path, int length, double eta); /* Dijkstra terminou          */
  void (*move)(int from, int to, double t0, double t1);  /* carro percorreu a aresta   */
  void (*update)(int from, int to, double kmh, double t);/* atualização aplicada       */
  void (*replan)(int at, double t);                      /* vai rodar Dijkstra de novo */
  void (*done)(double time, double km);                  /* chegou                     */
} TraceHooks;
extern TraceHooks trace;
```

`dijkstra` chama `trace.pop`/`trace.relax`/`trace.plan` se não forem
`NULL`; `calculate_path` chama `move`/`update`/`replan`/`done`. Custo zero
no CLI: sete comparações com `NULL`.

### 1.2 `run_trace`

Em `src/trace.c`:

```c
int run_trace(const char *input);   /* 0 = ok, !=0 = entrada inválida */
```

Abre a string com `fmemopen`, reaproveita `read_file_header`/`read_edges`/
`read_updates`, instala hooks que fazem `printf` de uma linha por evento e
roda `calculate_path`. Formato de saída, uma linha por evento, campos
separados por espaço, tempos em segundos com 3 casas:

```
graph 6 9
edge 1 2 1000 60.000
...
pop 1 0.000
relax 1 2 60.000
relax 1 3 90.000
pop 2 60.000
...
plan 1 2 4 6 180.000
move 1 2 0.000 60.000
update 2 4 5.000 60.000
replan 2 60.000
pop 2 0.000
...
plan 2 5 6 180.000
move 2 5 60.000 210.000
move 5 6 210.000 240.000
done 240.000 4.000
```

`graph`/`edge` no início dão ao JS o estado inicial sem parse duplicado da
entrada. Tempos de `pop`/`relax` dentro de um replanejamento são relativos
ao nó de partida (é o que o C calcula); o JS soma o relógio.

`calculate_path` sai de `main.c` para `src/route.c` (+ `include/route.h`),
sem mudar uma linha do corpo: é o que o CLI e o `run_trace` compartilham,
e o build WASM não inclui `main.c`. `main.c` fica só com o CLI
(`main`, `write_output`, `format_time`). `run_trace` é exportada para o
WASM; no build nativo fica disponível por um alvo `make trace` que lê
stdin, útil para os testes do repo.

### 1.3 Correções

- `format_time`: arredondar `total_time` para milissegundos antes de
  decompor (`00:02:60` → `00:03:00`).
- `read_updates`: o `fscanf("%[^\n]\n", aux)` com `char aux[50]` estoura em
  linhas longas; trocar por contagem de `\n` com `fgetc`. Sem atualizações
  hoje funciona por sorte (`feof` já verdadeiro); passa a ser explícito.
- `find_adj_list`/`update_adj` percorrem a lista sem checar `NULL`: uma
  atualização de aresta inexistente derruba o programa. Passam a ignorar
  com aviso no stderr — a entrada do editor de trânsito vem do usuário.

### 1.4 README e testes

README com: o problema, formato de entrada, como compilar e rodar, o modo
trace e seu formato, créditos aos três autores, link para a página do site.
`test/` com o cenário acima e a saída esperada do CLI, e um script
`test/run.sh` que compila e compara — a saída esperada é capturada **antes**
de qualquer mudança nesta branch, para provar que a instrumentação não
altera o resultado.

## Seção 2 — Receita de build no site

- `build/routes/Dockerfile` (`emscripten/emsdk:6.0.8`, git) e
  `build/routes/build.sh`: clona o upstream, `checkout --detach` no SHA
  fixo `REPO_ROUTES`/`SHA_ROUTES` (constantes no Rakefile, como o 2D),
  compila todos os `src/*.c` **menos `main.c`**:

  ```
  emcc -Os src/PQ.c src/adjacency.c src/algorithm.c src/edge.c \
       src/updates.c src/util.c src/route.c src/trace.c \
       -sMODULARIZE=1 -sEXPORT_NAME=criarRotas \
       -sEXPORTED_FUNCTIONS=_run_trace,_malloc,_free \
       -sEXPORTED_RUNTIME_METHODS=ccall,stringToUTF8,lengthBytesUTF8 \
       -sALLOW_MEMORY_GROWTH=0 -sEXIT_RUNTIME=0 \
       -o /out/rotas.js
  ```

  Sem `main.c` o módulo não tenta rodar nada ao carregar; `run_trace` é
  chamada por `ccall` com a entrada como string. A saída chega pelo
  callback `print` do módulo.
- `rake routes:build` no Rakefile. Artefatos versionados em
  `src/demos/car-routes/rotas.js` e `rotas.wasm` (esperado: < 60 KB
  somados com `-Os`).
- `build.sh` falha alto se `git rev-parse HEAD` não bater com o SHA.
- `test/routes_artifacts_test.rb`: os dois artefatos existem em `src/` e
  em `output/`, com piso de tamanho (`rotas.wasm` ≥ 20 KB, `rotas.js` ≥
  20 KB) — mesmo formato do `wasm_artifacts_test.rb`.

## Seção 3 — Cenários e player

### 3.1 Cenários

`src/demos/car-routes/cenarios.json`, publicado como está (o JS busca por
`fetch`):

```json
{
  "engarrafamento": {
    "nos":  [{ "id": 1, "x": 0.1, "y": 0.5 }, ...],
    "arestas": [{ "de": 1, "para": 2, "m": 1000 }, ...],
    "origem": 1, "destino": 6, "kmh": 60,
    "atualizacoes": [{ "t": 30, "de": 2, "para": 4, "kmh": 5 }]
  }
}
```

`x`/`y` em [0,1] — o formato do trabalho não tem coordenadas, elas existem
só para desenhar. `gerarEntrada(cenario)` produz o texto no formato do C.

Quatro cenários:

| id | o que mostra |
|---|---|
| `dijkstra` | grade 4×4 sem atualizações: só a fronteira crescendo e o caminho |
| `engarrafamento` | a via mais rápida trava (60→5 km/h) antes de o carro chegar; ele desvia |
| `tarde-demais` | a mesma via trava depois que o carro já entrou nela: replanejar só vale a partir do próximo nó |
| `via-libera` | uma via lenta fica rápida no meio do trajeto e o carro muda para aproveitar |

### 3.2 Player

`frontend/javascript/routes-player.js`, importado por `index.js` como os
outros players. Monta em cada `<div class="rotas" data-rotas="<id>">` da
página:

- `<canvas>` responsivo (largura do container, proporção 3:2), com
  `devicePixelRatio`;
- controles: play/pause, passo (um evento), velocidade 1×/4×, reiniciar;
- painel: relógio simulado, fila de prioridade atual (`id: tempo`,
  ordenada), km e tempo acumulados;
- legenda.

Desenho a cada frame a partir do estado reconstruído dos eventos até o
índice atual:

- arestas: espessura proporcional a km/h, seta na ponta; via atualizada
  pisca na cor de acento por ~1 s de simulação;
- nós: aberto (na fila) com contorno de acento; fechado (`pop`) preenchido
  com `--muted`; origem e destino rotulados;
- `relax`: linha de acento da aresta por um instante;
- caminho planejado tracejado; percorrido sólido;
- carro: círculo pequeno interpolado linearmente ao longo do `move` no
  relógio simulado.

Cores lidas dos tokens (`--fg`, `--bg`, `--muted`, `--accent`, `--border`)
via `getComputedStyle` a cada frame — segue o tema e o fade do toggle.

Tempo simulado vs. tempo real: `pop`/`relax` são passos discretos (um a
cada 250 ms em 1×); `move` avança o relógio simulado com escala fixa
(ex.: 1 s real = 60 s simulados em 1×). O player expõe `passo()` para
avançar um evento com o player pausado.

O WASM é carregado **uma vez por página** e sob demanda: até o primeiro
play todo player mostra o estado inicial desenhado a partir do JSON (não
precisa do C para isso), como o botão "jogar" do 2D. Sem JS a página
mostra o texto e um link para o repo (`<noscript>`).

### 3.3 Editor de trânsito

Só no player com `data-rotas-editor`. Clicar numa aresta abre um form
inline (instante em segundos, nova velocidade em km/h, "Aplicar"); as
atualizações adicionadas aparecem numa lista com "remover". "Rodar de
novo" ordena as atualizações por instante, regenera a entrada, chama
`run_trace` e reinicia o player. "Restaurar cenário" volta ao JSON.
Validação no JS: aresta existe, instante ≥ 0, velocidade > 0; o C ignora o
resto com aviso (1.3).

### 3.4 Partial e front matter

`demo.type: routes` no front matter → `src/_partials/demos/_routes.erb`
renderiza o player principal com editor (`data-rotas="engarrafamento"
data-rotas-editor`). Os demais players vêm de `<div>`s no corpo do
markdown, dentro do `project-body`. `demo_partial_for` já resolve por tipo.

## Seção 4 — Conteúdo (pt e en)

`src/_projects/car-routes.{pt,en}.md`:

```yaml
title: Rotas com trânsito em C
slug: car-routes
year: 2023
featured: true
order: 4
summary: Caminho mais rápido num mapa cujo trânsito muda enquanto o carro anda — Dijkstra com fila de prioridade, replanejado a cada atualização, rodando aqui compilado para WebAssembly.
tech: [C, Dijkstra, Emscripten, WebAssembly]
repo: https://github.com/viniciuscole/car-routes-optimazing
demo:
  type: routes
```

Seções do texto, cada uma com o player indicado:

1. **O problema** — cidade como grafo direcionado, velocidade que muda com
   o tempo. Player principal (`engarrafamento`, com editor): "trave uma via
   e veja o carro desviar".
2. **Peso é tempo** — por que distância não serve: 3 km a 60 km/h perdem
   para 4 km a 90. Fórmula `m / (km/h ÷ 3,6)` e onde ela está no C
   (`calculate_weight`).
3. **Dijkstra passo a passo** — player `dijkstra`. A invariante (nó fechado
   tem tempo ótimo), o relaxamento, por que funciona com pesos positivos.
   Trecho de `updateDistanceCallback` comentado.
4. **A fila de prioridade** — o heap de `PQ.c`; por que O((V+E) log V);
   o que acontece sem heap (busca linear, O(V²)).
5. **Quando o trânsito muda** — players `engarrafamento`, `tarde-demais`,
   `via-libera`. O loop de `calculate_path`: anda até o instante, aplica,
   replaneja de onde está. O caso "tarde demais" mostra o limite: o carro
   não volta.
6. **Limitações e o que faria diferente** — recalcular do zero vs.
   incremental (D* Lite / LPA*); atualizações são conhecidas de antemão
   (o programa lê o futuro, um carro real não); velocidade inicial única;
   O(V) por passo do carro por reconstruir o caminho.
7. **Créditos** — os três autores com links; o que cada um fez, se
   Vinicius souber dizer.

## Seção 5 — Testes e verificação

**No upstream:** `test/run.sh` compila o CLI e compara a saída do cenário
com a esperada (capturada antes de qualquer mudança); compila o `make
trace` e confere que o trace termina em `done 240.000 4.000`.

**No site (Ruby, `rake check`):**
- artefatos versionados e publicados (Seção 2);
- `cenarios.json` publicado e coerente: todo `de`/`para` existe em `nos`,
  `origem ≠ destino`, atualizações ordenadas por `t`, coordenadas em [0,1];
- a página existe em pt e en, tem o partial `_routes.erb` e todo
  `data-rotas` do corpo referencia um cenário do JSON;
- o bundle publicado contém `routes-player`.

**No navegador:** `rake routes:verify`, no container Playwright do 2D
(`mcr.microsoft.com/playwright:v1.56.0-noble`): abre a página construída,
dispara o player `engarrafamento`, espera `done`, e afirma que o caminho
final é `1 2 5 6` e que o canvas tem pixels na cor de acento (algo foi
desenhado). Roda sob demanda como o `demo2d:verify`, não na CI.

## Fora de escopo

- Grafos grandes (mapas reais, OSM): o desenho e o trace em lote são
  dimensionados para dezenas de nós.
- Algoritmos incrementais: a página explica, não implementa.
- Cenários editáveis além das atualizações de trânsito (adicionar nós ou
  vias).
