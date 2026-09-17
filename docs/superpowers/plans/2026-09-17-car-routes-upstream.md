# Modo trace no car-routes-optimazing — Plano de Implementação (1 de 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao `car-routes-optimazing` um modo que roda a simulação inteira e emite um evento por linha, sem mudar o CLI, para o site compilá-lo em WebAssembly e animar o Dijkstra replanejado.

**Architecture:** `calculate_path` sai de `main.c` para `route.c`, ganha ganchos opcionais (`TraceHooks`, `NULL` por padrão) e passa a ser compartilhada pelo CLI e por `run_trace(const char *input)`, que lê a entrada de uma string via `fmemopen` e imprime os eventos no stdout. Três correções de robustez entram porque a entrada do editor de trânsito do site vem do leitor.

**Tech Stack:** C (gcc, `-std=gnu99` por causa do `fmemopen`), make, bash para os testes. Sem dependências.

**Spec:** `docs/superpowers/specs/2026-09-17-car-routes-design.md` (no repositório do site), Seção 1.

## Global Constraints

- **Repositório:** `https://github.com/viniciuscole/car-routes-optimazing`, clonado em `$CLAUDE_JOB_DIR/tmp/routes` (já existe; se não, clonar de novo). Trabalho na branch **`trace-mode`**, a partir de `main` (`63a34a8`).
- **O CLI não muda:** `./trab2 entrada saida` produz a mesma saída antes e depois, fora a correção do `00:02:60`. O teste de baseline (Task 1) é capturado **antes** de qualquer outra mudança e nunca é editado depois, salvo na Task 5, que altera só a linha que o bug afetava.
- **Código, identificadores e comentários em inglês** (regra do README do repo: "All code will be written in English"). Mensagens de commit em inglês, sem emoji.
- **Comentários só em hacks** — coisas impossíveis de entender sem o comentário. O resto se explica.
- **Autoria git:** nunca passar `--author` nem `-c user.*`; a identidade global já está certa.
- **Formato do trace** (uma linha por evento, campos separados por espaço, tempos em segundos com 3 casas, km/h com 3 casas, km com 3 casas):

  ```
  graph N E
  edge FROM TO METERS KMH
  replan NODE CLOCK
  pop NODE TIME
  relax FROM TO TIME
  plan N1 N2 ... Nk ETA
  move FROM TO T0 T1
  update FROM TO KMH CLOCK
  unreachable NODE CLOCK
  done CLOCK KM
  ```

  `pop`/`relax`/`plan` são relativos ao nó do `replan` que os precede (tempo 0 nele). `move`/`update`/`done` usam o relógio absoluto.

## Estrutura de arquivos

| arquivo | ação | responsabilidade |
|---|---|---|
| `test/with_update.txt`, `test/with_update.expected` | criar | cenário de 6 nós com engarrafamento e saída esperada do CLI |
| `test/no_update.txt`, `test/no_update.expected` | criar | mesmo grafo sem atualizações (expõe o bug de formatação) |
| `test/with_update.trace` | criar | trace esperado do cenário com engarrafamento |
| `test/run.sh` | criar | compila, roda os cenários, compara byte a byte |
| `include/route.h`, `src/route.c` | criar | `calculate_path`, movida de `main.c` |
| `include/trace.h`, `src/trace.c` | criar | `TraceHooks trace`, `run_trace` |
| `src/trace_main.c` | criar | `main` do binário `trace`: lê stdin, chama `run_trace` |
| `src/main.c` | modificar | perde `calculate_path`; ganha o arredondamento em `format_time` |
| `src/algorithm.c` | modificar | chama `trace.pop`/`trace.relax`/`trace.plan`/`trace.unreachable` |
| `src/adjacency.c`, `include/adjacency.h` | modificar | `list_for_each`; `find_adj_list`/`update_adj` sem crash em aresta inexistente |
| `src/util.c` | modificar | `read_updates` sem buffer fixo |
| `makefile` | modificar | alvo `trace`; `-std=gnu99` |
| `README.md` | reescrever | problema, formato, uso, modo trace, créditos |

---

### Task 1: Baseline — capturar a saída do CLI antes de mexer

**Files:**
- Create: `test/with_update.txt`, `test/no_update.txt`, `test/with_update.expected`, `test/no_update.expected`, `test/run.sh`

**Interfaces:**
- Produces: `test/run.sh` (exit 0 = tudo igual ao esperado) — todas as tasks seguintes rodam este script.

- [ ] **Step 1: Criar a branch**

```bash
cd $CLAUDE_JOB_DIR/tmp/routes
git checkout main && git pull --ff-only
git checkout -b trace-mode
```

- [ ] **Step 2: Escrever os dois cenários**

`test/with_update.txt`:
```
6;9
1;6
60
1;2;1000
1;3;1500
2;4;1000
3;4;800
2;5;2500
4;6;1000
5;6;500
3;5;3000
4;5;600
30;2;4;5
```

`test/no_update.txt`: as 12 primeiras linhas do arquivo acima (sem a linha `30;2;4;5`).

- [ ] **Step 3: Compilar o CLI atual e capturar as saídas**

```bash
gcc -O2 -o trab2 src/*.c -lm
./trab2 test/with_update.txt test/with_update.expected
./trab2 test/no_update.txt test/no_update.expected
cat test/with_update.expected test/no_update.expected
```

Esperado (confirmado no probe da spec):
```
1;2;5;6
4.000000
00:04:0.0000001;2;4;6
3.000000
00:02:60.000000
```
(o `.expected` não termina em `\n`, como o CLI escreve.) O `00:02:60` é o bug; fica assim **por enquanto** para o baseline ser honesto. A Task 5 corrige o arquivo junto com o código.

- [ ] **Step 4: Escrever `test/run.sh`**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

gcc -std=gnu99 -O1 -g -fsanitize=address,undefined -Wall -o trab2 src/*.c -lm

fail=0
for case in with_update no_update; do
  ./trab2 "test/$case.txt" "test/$case.out"
  if cmp -s "test/$case.out" "test/$case.expected"; then
    echo "ok    $case"
  else
    echo "FAIL  $case"; diff "test/$case.expected" "test/$case.out" || true; fail=1
  fi
done
exit $fail
```

`chmod +x test/run.sh`. Atenção: `src/*.c` vai incluir `trace_main.c` na Task 4 e o link falharia com dois `main` — a Task 4 ajusta o script para excluir esse arquivo.

- [ ] **Step 5: Rodar e ver passar**

Run: `test/run.sh`
Expected: `ok    with_update` / `ok    no_update`, exit 0.

- [ ] **Step 6: Provar por remoção**: troque `1;2;5;6` por `1;2;4;6` em `with_update.expected`, rode, veja `FAIL with_update`, desfaça.

- [ ] **Step 7: Ignorar os gerados e commitar**

Acrescentar ao `.gitignore`: `test/*.out` e `trace` (o binário da Task 4). Conferir que `trab2` e `obj/` já estão ignorados (`git status` limpo fora de `test/` e `.gitignore`).

```bash
git add .gitignore test/
git commit -m "Add CLI baseline tests"
```

---

### Task 2: Mover `calculate_path` para `route.c`

**Files:**
- Create: `include/route.h`, `src/route.c`
- Modify: `src/main.c` (remover `calculate_path` e seu protótipo; incluir `route.h`)

**Interfaces:**
- Produces: `void calculate_path(AdjList **adjacency_vector, Update *velocity_updates, int node_amount, int edge_amount, int updates_amount, int main_src_node, int main_dest_node, int *path, double *total_time, double *total_distance, int *path_length);` em `route.h` — mesma assinatura de hoje.

- [ ] **Step 1: Criar `include/route.h`**

```c
#ifndef route_h
#define route_h

#include "adjacency.h"
#include "updates.h"

void calculate_path(AdjList **adjacency_vector, Update *velocity_updates, int node_amount, int edge_amount,
                    int updates_amount, int main_src_node, int main_dest_node, int *path, double *total_time,
                    double *total_distance, int *path_length);

#endif
```

- [ ] **Step 2: Criar `src/route.c`** com os includes que `calculate_path` usa e o corpo **idêntico** ao de `main.c` (recortar e colar, sem editar uma linha):

```c
#include "../include/route.h"
#include "../include/algorithm.h"
#include <stdlib.h>

void calculate_path(/* ...assinatura acima... */)
{
  /* corpo atual de main.c:52-103, sem alteracao */
}
```

- [ ] **Step 3: Em `src/main.c`**, apagar o protótipo (linha 9-10) e a definição (52-103) de `calculate_path`; acrescentar `#include "../include/route.h"`.

- [ ] **Step 4: Rodar** `test/run.sh` → os dois `ok`. `git diff --stat` deve mostrar `main.c` só com remoções + 1 include.

- [ ] **Step 5: Commit**

```bash
git add include/route.h src/route.c src/main.c
git commit -m "Move calculate_path out of main.c"
```

---

### Task 3: Ganchos de instrumentação

**Files:**
- Create: `include/trace.h`
- Modify: `src/algorithm.c`, `src/route.c`

**Interfaces:**
- Produces: `TraceHooks trace` (global, campos `NULL` por padrão). Quem instala ganchos escreve nos campos; quem não instala não paga nada.

- [ ] **Step 1: Criar `include/trace.h`**

```c
#ifndef trace_h
#define trace_h

typedef struct {
  void (*pop)(int node, double time);
  void (*relax)(int from, int to, double new_time);
  void (*plan)(const int *path, int length, double eta);
  void (*unreachable)(int node, double clock);
  void (*replan)(int node, double clock);
  void (*move)(int from, int to, double t0, double t1);
  void (*update)(int from, int to, double kmh, double clock);
  void (*done)(double clock, double km);
} TraceHooks;

extern TraceHooks trace;

int run_trace(const char *input);

#endif
```

- [ ] **Step 2: Definir a global** — no topo de `src/route.c`, após os includes: `TraceHooks trace = {0};` e `#include "../include/trace.h"`.

- [ ] **Step 3: Instrumentar `dijkstra` em `src/algorithm.c`** (`#include "../include/trace.h"`):

  - dentro do `while (pq->N != 0)`, logo após `visited[v_id] = 1;`:
    ```c
    if (trace.pop) trace.pop(v_id, time[v_id]);
    ```
  - em `updateDistanceCallback`, logo após `path[w_id] = v_id;`:
    ```c
    if (trace.relax) trace.relax(v_id, w_id, time[w_id]);
    ```
  - após `savePath(...)` e a cópia para `path`, antes de `PQ_finish`:
    ```c
    if (trace.plan) trace.plan(path, *path_length, time[main_dest_node]);
    ```

  Cuidado: o `pop` de um nó pode acontecer mais de uma vez? Não — `visited` só bloqueia relaxamentos, mas a PQ pode conter o mesmo nó duas vezes (inserção sem decrease-key). Então **`pop` duplicado acontece** para nós inseridos com dois tempos. Para o trace ficar limpo, só emitir quando é a primeira vez: mover o `trace.pop` para dentro de um `if (!visited[v_id])` que envolve o marcador e a travessia:
    ```c
    Adj v = PQ_delmin(pq);
    int v_id = id(v);
    if (visited[v_id]) continue;
    visited[v_id] = 1;
    if (trace.pop) trace.pop(v_id, time[v_id]);
    ```
  Isso também poupa travessias repetidas — sem mudar resultado, porque um nó já visitado nunca relaxa ninguém (o `visited[w_id] == 0` do callback é sobre o vizinho, não sobre `v`; mas os vizinhos de um `v` já fechado só melhorariam se `time[v]` tivesse diminuído, o que não acontece após fechar). Rodar `test/run.sh` prova.

- [ ] **Step 4: Instrumentar `calculate_path` em `src/route.c`**:

  - antes de **cada** chamada a `dijkstra` (há duas): `if (trace.replan) trace.replan(path[path_length[0]], total_time[0]);`
  - nas duas partes que somam tempo/distância e fazem `path[++path_length[0]] = ...`, capturar antes/depois:
    ```c
    double t0 = total_time[0];
    total_time[0] += get_time(...);
    total_distance[0] += get_distance(...);
    if (trace.move) trace.move(temporary_path[index_temporary_path - 1], temporary_path[index_temporary_path], t0, total_time[0]);
    path[++path_length[0]] = temporary_path[index_temporary_path++];
    ```
  - no `update_adj(...)` do loop de atualizações, logo após:
    ```c
    if (trace.update) trace.update(get_src_node(velocity_updates[index_uptades]), get_dest_node(velocity_updates[index_uptades]), get_new_velocity(velocity_updates[index_uptades]), total_time[0]);
    ```
    (antes do `index_uptades++`.)
  - nos dois pontos de saída (o `return` dentro do loop e o fim da função): `if (trace.done) trace.done(total_time[0], total_distance[0] / 1000.0);` antes do `free(temporary_path)`.

- [ ] **Step 5: Rodar** `test/run.sh` → os dois `ok` (nenhum gancho instalado; o CLI não muda).

- [ ] **Step 6: Commit**

```bash
git add include/trace.h src/algorithm.c src/route.c
git commit -m "Add optional trace hooks to dijkstra and calculate_path"
```

---

### Task 4: `run_trace` e o binário `trace`

**Files:**
- Create: `src/trace.c`, `src/trace_main.c`, `test/with_update.trace`
- Modify: `src/adjacency.c`, `include/adjacency.h` (`list_for_each`), `makefile`, `test/run.sh`

**Interfaces:**
- Consumes: `calculate_path` (Task 2), `TraceHooks trace` (Task 3), `read_file_header`/`read_edges`/`read_updates` de `util.h`.
- Produces: `int run_trace(const char *input)` — imprime o trace no stdout, retorna 0. `void list_for_each(AdjList *list, void (*fn)(Adj adj, void *ctx), void *ctx)`.

- [ ] **Step 1: Escrever o trace esperado** em `test/with_update.trace`. Foi calculado à mão a partir do código: `list_push` insere no **fim** (os `relax` de cada `pop` saem na ordem das arestas no arquivo); a PQ é de mínimo e recebe duplicatas (um nó pode ser inserido com dois tempos), mas com a guarda `visited` da Task 3 cada `pop` sai uma vez, em ordem não-decrescente de tempo; o Dijkstra roda até a fila esvaziar, então nós fechados depois do destino (`pop 4 720`) também aparecem. Após a única atualização o loop externo termina e só o Dijkstra final ("No updates left") roda a partir do nó 2 — um `replan 2`, não dois.

```
graph 6 9
edge 1 2 1000 60.000
edge 1 3 1500 60.000
edge 2 4 1000 60.000
edge 2 5 2500 60.000
edge 3 4 800 60.000
edge 3 5 3000 60.000
edge 4 6 1000 60.000
edge 4 5 600 60.000
edge 5 6 500 60.000
replan 1 0.000
pop 1 0.000
relax 1 2 60.000
relax 1 3 90.000
pop 2 60.000
relax 2 4 120.000
relax 2 5 210.000
pop 3 90.000
pop 4 120.000
relax 4 6 180.000
relax 4 5 156.000
pop 5 156.000
pop 6 180.000
plan 1 2 4 6 180.000
move 1 2 0.000 60.000
update 2 4 5.000 60.000
replan 2 60.000
pop 2 0.000
relax 2 4 720.000
relax 2 5 150.000
pop 5 150.000
relax 5 6 180.000
pop 6 180.000
pop 4 720.000
plan 2 5 6 180.000
move 2 5 60.000 210.000
move 5 6 210.000 240.000
done 240.000 4.000
```

Conferências que valem a pena refazer se algo divergir: `pop 3 90` não relaxa ninguém (3→4 daria 138 > 120; 3→5 daria 270 > 210); `pop 5 156` não relaxa 6 (186 > 180); no segundo Dijkstra 2→4 custa 1000 m a 5 km/h = 720 s.

- [ ] **Step 2: `list_for_each` em `adjacency.c`/`adjacency.h`**

```c
void list_for_each(AdjList *list, void (*fn)(Adj adj, void *ctx), void *ctx)
{
    for (Cell *cell = list->first; cell != NULL; cell = cell->next)
        fn(cell->adj, ctx);
}
```
Protótipo no header. (Ver como `Cell` e `first` se chamam em `adjacency.c` e usar os nomes reais.)

- [ ] **Step 3: Escrever `src/trace.c`**

```c
#include "../include/trace.h"
#include "../include/route.h"
#include "../include/util.h"
#include <stdio.h>
#include <stdlib.h>

static void on_pop(int node, double time) { printf("pop %d %.3f\n", node, time); }
static void on_relax(int from, int to, double t) { printf("relax %d %d %.3f\n", from, to, t); }
static void on_plan(const int *path, int length, double eta)
{
    printf("plan");
    for (int i = 0; i < length; i++) printf(" %d", path[i]);
    printf(" %.3f\n", eta);
}
static void on_unreachable(int node, double clock) { printf("unreachable %d %.3f\n", node, clock); }
static void on_replan(int node, double clock) { printf("replan %d %.3f\n", node, clock); }
static void on_move(int from, int to, double t0, double t1) { printf("move %d %d %.3f %.3f\n", from, to, t0, t1); }
static void on_update(int from, int to, double kmh, double clock) { printf("update %d %d %.3f %.3f\n", from, to, kmh, clock); }
static void on_done(double clock, double km) { printf("done %.3f %.3f\n", clock, km); }

static void print_edge(Adj adj, void *ctx)
{
    int from = *(int *)ctx;
    double kmh = get_distance(adj) / get_time(adj) * 3.6;
    printf("edge %d %d %.0f %.3f\n", from, get_node_id(adj), get_distance(adj), kmh);
}

int run_trace(const char *input)
{
    FILE *file = fmemopen((void *)input, strlen(input), "r");
    if (!file) return 1;

    int node_amount = 0, edge_amount = 0, updates_amount = 0, src = 0, dest = 0;
    double velocity = 0;
    read_file_header(&node_amount, &edge_amount, &src, &dest, &velocity, file);
    if (node_amount <= 0 || edge_amount < 0 || src < 1 || src > node_amount || dest < 1 || dest > node_amount || velocity <= 0) {
        fclose(file);
        return 2;
    }
    AdjList **graph = read_edges(file, node_amount, edge_amount, velocity);
    Update *updates = read_updates(file, &updates_amount);
    fclose(file);

    printf("graph %d %d\n", node_amount, edge_amount);
    for (int i = 1; i <= node_amount; i++) list_for_each(graph[i - 1], print_edge, &i);

    trace.pop = on_pop; trace.relax = on_relax; trace.plan = on_plan; trace.unreachable = on_unreachable;
    trace.replan = on_replan; trace.move = on_move; trace.update = on_update; trace.done = on_done;

    int *path = calloc(node_amount + 1, sizeof(int));
    double total_time = 0, total_distance = 0;
    int path_length = 0;
    calculate_path(graph, updates, node_amount, edge_amount, updates_amount, src, dest, path, &total_time, &total_distance, &path_length);
    fflush(stdout);

    free(path);
    free(updates);
    end_list_vector(graph, node_amount);
    return 0;
}
```
`#include <string.h>` para `strlen`. `fmemopen` exige `_GNU_SOURCE`/`gnu99` (por isso o `-std=gnu99` nas builds).

- [ ] **Step 4: `src/trace_main.c`**

```c
#include "../include/trace.h"
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    int c;
    while ((c = fgetc(stdin)) != EOF) {
        if (len + 1 >= cap) buf = realloc(buf, cap *= 2);
        buf[len++] = (char)c;
    }
    buf[len] = '\0';
    int rc = run_trace(buf);
    free(buf);
    return rc;
}
```

- [ ] **Step 5: makefile** — acrescentar `-std=gnu99` em `FLAGS` e no comando de compilação de objetos; excluir `trace_main.c` dos objetos do `trab2` e criar o alvo:

```make
C_FILES        = $(filter-out $(SRC)/trace_main.c, $(wildcard $(SRC)/*.c))
...
trace: $(OBJ_FILES)
	@ $(COMPILER) $(SRC)/trace_main.c $(filter-out $(OBJ)/main.o, $(OBJ_FILES)) -o trace $(FLAGS)
```
(`$(filter-out ...)` tira o `main.o` do CLI para não haver dois `main`.)

- [ ] **Step 6: Atualizar `test/run.sh`**: a compilação do CLI passa a excluir `trace_main.c`, e o script ganha o caso do trace:

```bash
SAN="-std=gnu99 -O1 -g -fsanitize=address,undefined -Wall"
gcc $SAN -o trab2 $(ls src/*.c | grep -v trace_main.c) -lm
gcc $SAN -o trace $(ls src/*.c | grep -v '/main.c') -lm
...
./trace < test/with_update.txt > test/with_update.trace.out
if cmp -s test/with_update.trace.out test/with_update.trace; then echo "ok    trace"; else echo "FAIL  trace"; diff test/with_update.trace test/with_update.trace.out || true; fail=1; fi
```

- [ ] **Step 7: Rodar** `test/run.sh` → três `ok`. Se `trace` divergir, o `diff` aponta a linha; refazer a conta daquela linha à mão (ver Step 1) antes de decidir se o erro é do código ou do esperado.

- [ ] **Step 8: Commit**

```bash
git add src/trace.c src/trace_main.c src/adjacency.c include/adjacency.h makefile test/
git commit -m "Add run_trace and the trace binary"
```

---

### Task 5: Correções de robustez

**Files:**
- Modify: `src/main.c` (`format_time`), `src/util.c` (`read_updates`), `src/adjacency.c` (`find_adj_list`, `update_adj`), `src/route.c`/`src/algorithm.c` (destino inalcançável)
- Create: `test/bad_update.txt`, `test/bad_update.expected`, `test/unreachable.txt`, `test/unreachable.trace`
- Modify: `test/no_update.expected` (só a última linha), `test/run.sh`

- [ ] **Step 0: capacidade da fila** — `PQ_init(pq, edge_amount)` em `algorithm.c` aloca `pq->map` com `E+1` posições, mas `map` é indexado por **id de nó** (`map[id(v)]` em `PQ_insert`). Com mais nós que `E+1` (o cenário inalcançável do Step 4: 3 nós, 1 aresta) é escrita fora do array — o ASan do `run.sh` acusa. Trocar por `PQ_init(pq, edge_amount > node_amount ? edge_amount : node_amount);`. O `pq->pq` não precisa de mais: o tamanho simultâneo da fila nunca passa do número de relaxamentos (≤ E), porque a origem é removida antes do primeiro relaxamento.

- [ ] **Step 1: `format_time`** — arredondar para milissegundos antes de decompor:

```c
char *format_time(double total_time)
{
    total_time = floor(total_time * 1000.0 + 0.5) / 1000.0;
    int whole = (int)floor(total_time);
    int hours = whole / 3600;
    int minutes = (whole % 3600) / 60;
    double seconds = total_time - hours * 3600 - minutes * 60;
    ...
```
(`#include <math.h>`; o `-lm` já está no link.) Trocar em `test/no_update.expected` a última linha para `00:03:0.000000`. Rodar `test/run.sh` → `ok`.

- [ ] **Step 2: `read_updates`** — contar linhas com `fgetc` (sem `char aux[50]`), e ler com `fscanf` só `line_count` vezes:

```c
long file_seek = ftell(file);
int line_count = 0, c, at_line_start = 1;
while ((c = fgetc(file)) != EOF) {
    if (at_line_start && c != '\n') line_count++;
    at_line_start = (c == '\n');
}
fseek(file, file_seek, SEEK_SET);
*updates_amount = line_count;
Update *updates = malloc(sizeof(Update) * (line_count > 0 ? line_count : 1));
for (int i = 0; i < line_count; i++) {
    if (fscanf(file, "%lf;%d;%d;%lf\n", &instant_time, &src_node, &dest_node, &new_velocity) != 4) { *updates_amount = i; break; }
    updates[i] = init_update(src_node, dest_node, instant_time, new_velocity);
}
return updates;
```
Teste: acrescentar ao `with_update.txt` uma segunda atualização com uma linha longa de lixo? Não — manter o arquivo do baseline intocado. Criar `test/long_line.txt` = `with_update.txt` + uma linha `9999;2;4;5;` seguida de 200 caracteres `#`. Esperado = `with_update.expected` (a atualização em 9999 s nunca chega; o lixo é ignorado pelo `fscanf` que retorna != 4 e encerra). Adicionar o caso ao loop do `run.sh`.

- [ ] **Step 3: aresta inexistente** — `find_adj_list` e `update_adj` percorrem até `NULL`; se não acharem, `update_adj` escreve `warning: no edge %d->%d, update ignored\n` no **stderr** e retorna; `find_adj_list` retorna `init_adj(0, 0, 0)` (id 0 nunca existe). `test/bad_update.txt` = `with_update.txt` com a atualização trocada por `30;2;6;5` (2→6 não existe). Esperado = `no_update.expected` (nada muda). Adicionar ao `run.sh` (o stderr vai para `/dev/null` no teste).

- [ ] **Step 4: destino inalcançável** — em `route.c`, após cada `dijkstra`, se `temp_path_length == 1 && temporary_path[0] != main_dest_node` (o `savePath` só devolve o próprio destino quando `path[dest] == 0`): `if (trace.unreachable) trace.unreachable(path[path_length[0]], total_time[0]);` e retornar sem `done`. No CLI, `write_output` continua escrevendo o caminho parcial — só não pode mais derrubar o programa. `test/unreachable.txt`:
```
3;1
1;3
60
1;2;1000
```
`test/unreachable.trace` esperado:
```
graph 3 1
edge 1 2 1000 60.000
replan 1 0.000
pop 1 0.000
relax 1 2 60.000
pop 2 60.000
plan 3 inf
unreachable 1 0.000
```
Conferir como `%.3f` imprime `__DBL_MAX__` (não é `inf`; é um número gigante). Melhor: em `on_plan`, imprimir `unreachable` no lugar do número quando `eta >= __DBL_MAX__`. Ajustar o esperado ao que ficar decidido. Adicionar o caso ao `run.sh` (rodando `./trace < test/unreachable.txt`).

- [ ] **Step 5: Rodar** `test/run.sh` → todos `ok` (with_update, no_update, long_line, bad_update, trace, unreachable).

- [ ] **Step 6: Commit**

```bash
git add src/ test/
git commit -m "Harden input handling and fix time formatting"
```

---

### Task 6: README

**Files:**
- Rewrite: `README.md`

- [ ] **Step 1: Escrever** (em inglês, como o resto do repo), com estas seções: **What it does** (o parágrafo "O problema que o C resolve" da spec, traduzido); **Input format** (o bloco da spec); **Build and run** (`make`, `./trab2 input output`; `make trace`, `./trace < input`); **Trace mode** (o formato de eventos do Global Constraints, com um exemplo de 10 linhas); **Tests** (`test/run.sh`); **Authors** — Vinicius Cole ([viniciuscole](https://github.com/viniciuscole)), João ([vortex2jm](https://github.com/vortex2jm)), Gabriel Gatti ([gabrielgatti7](https://github.com/gabrielgatti7)); *Técnicas de Busca e Ordenação, UFES, 2023*; **See it running**: link para `https://viniciuscole.dev/projects/car-routes/` (a página vai existir ao fim do plano 2). Manter as seções **Patterns**/**Remarks** atuais no fim.

- [ ] **Step 2: Commit e push**

```bash
git add README.md
git commit -m "Write a real README"
git push -u origin trace-mode
```

---

### Task 7: Pull request

- [ ] **Step 1: Abrir o PR** contra `main`:

```bash
gh pr create --base main --head trace-mode --title "Add trace mode for the web visualization" --body-file - <<'EOF'
## What

- `calculate_path` moves to `route.c` so the CLI and the new `run_trace` share it.
- Optional `TraceHooks` (all NULL by default) in `dijkstra` and `calculate_path`; the CLI is untouched.
- `run_trace(const char *input)` runs the whole simulation from a string and prints one event per line (`graph`, `edge`, `replan`, `pop`, `relax`, `plan`, `move`, `update`, `unreachable`, `done`). `make trace` builds a stdin reader around it.
- Fixes: `00:02:60` time formatting (float rounding), fixed-size buffer in `read_updates`, crash on updates to non-existent edges, crash when the destination is unreachable.
- README.

## Why

viniciuscole.dev compiles this to WebAssembly and animates Dijkstra and the re-planning on the project page.

## Tests

`test/run.sh` — CLI output captured before any change, plus trace and edge-case scenarios.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

- [ ] **Step 2: Registrar o SHA** da ponta da branch (`git rev-parse HEAD`) — o plano 2 (site) precisa dele em `SHA_ROUTES`. Após o merge, trocar pelo SHA do merge commit.

---

## Self-review

- **Spec 1.1** (hooks) → Task 3. **1.2** (`run_trace`, `route.c`, `make trace`, formato) → Tasks 2 e 4. **1.3** (três correções + inalcançável) → Task 5. **1.4** (README, testes com baseline capturado antes) → Tasks 1 e 6.
- Assinaturas: `TraceHooks` (Task 3) é a que `trace.c` (Task 4) preenche; `run_trace` está declarada em `trace.h` (Task 3) e definida na Task 4; `list_for_each` definida e usada na Task 4.
- O formato do trace no Global Constraints bate com `on_*` da Task 4, com a exceção decidida na Task 5 Step 4 (`plan ... unreachable` para eta infinita) — quem executar atualiza o Global Constraints se mudar.
