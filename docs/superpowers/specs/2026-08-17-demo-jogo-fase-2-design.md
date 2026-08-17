# Demo jogável do jogo da velha em assembly — Fase 2

**Data:** 2026-08-17
**Status:** aprovado para planejamento
**Fase:** 2 de 2
**Spec da Fase 1:** `docs/superpowers/specs/2026-08-16-viniciuscole-dev-site-design.md`

## Objetivo

Fazer o [tic-tac-toe-assembly](https://github.com/viniciuscole/tic-tac-toe-assembly)
— um jogo da velha escrito em assembly x86 de 16 bits para DOS — rodar jogável
dentro da página do projeto em `viniciuscole.dev`, emulado no browser.

Esta é a prova de que o "ambiente para rodar projetos" construído na Fase 1
funciona: se um jogo de 1.747 linhas de assembly DOS pode ser embutido sem
alterar nenhum arquivo existente, o mecanismo está certo.

## O que já foi verificado na prática

Nada aqui é suposição. Tudo abaixo foi executado e observado antes desta spec
ser escrita.

**O executável monta e é válido** (verificado na Fase 1): `vca.asm` e `draw.asm`
montam com NASM 2.16.01 (`-f obj`) **sem nenhuma modificação no fonte**, e o
Open Watcom `wlink` produz um executável DOS de **3.244 bytes** com assinatura
`MZ` correta.

**O jogo roda e desenha.** Executado sob DOSBox 0.74-3 num container com display
virtual: o tabuleiro é traçado pelas rotinas de Bresenham do `draw.asm`, os
rótulos de posição (`11 12 13 / 21 22 23 / 31 32 33`) vêm do
`mens db '111213212223313233'` do segmento de dados, e as duas caixas de
comandos e erros aparecem. O comando `X11` desenhou o X na célula 11; o comando
`C22` desenhou o círculo no centro. Entrada de teclado, parser de comandos e as
duas primitivas gráficas confirmados funcionando.

**O comando do círculo é `C`, não `O`.** O readme do repositório do jogo diz
"Type OLC then press enter to play O", mas o código compara com `'C'`
(`vca.asm:80`), e foi `C22` que funcionou no teste. **O painel de instruções da
demo precisa documentar `C`.** Transcrever o readme documentaria um comando que
não existe.

**O js-dos roda o jogo num browser real.** Verificado pelo dono do projeto,
abrindo a página de teste montada durante o design.

**O Bridgetown copia os assets binários.** Verificado neste repositório:
arquivos `.wasm`, `.js` e `.jsdos` colocados em `src/vendor/` e `src/demos/`
aparecem em `output/` com os mesmos caminhos e o mesmo número de bytes. A
estratégia de vendorização abaixo depende disso, e não é suposição.

**A configuração do DOSBox usada no teste** — é ela que vai no bundle:

```
[dosbox]
machine=vgaonly

[cpu]
cycles=auto

[autoexec]
mount c .
c:
VCA.EXE
```

**Tamanhos medidos** (js-dos 8.4.1):

| Arquivo | Tamanho |
|---|---|
| `emulators/wdosbox.wasm` (DOSBox) | 1,4 MB |
| `emulators/wdosbox-x.wasm` (DOSBox-X) | 7,5 MB |
| `js-dos.js` | 316 KB |
| bundle `.jsdos` do jogo | 2,1 KB |
| pacote npm completo | 21 MB |

## Escopo

**Dentro:**

- Bundle `.jsdos` do jogo, versionado, com task para regenerá-lo
- js-dos vendorizado a partir do npm, servido da própria origem
- O partial `demos/_jsdos.erb` que o dispatcher da Fase 1 já sabe chamar
- Carregamento sob clique, com painel de instruções bilíngue
- Teclado na tela, para o jogo ser jogável no celular
- Tratamento visual CRT restrito à página do jogo
- Aviso de licença GPL

**Fora:**

- Som (o jogo não emite áudio)
- Save/load de partida
- Qualquer outro tipo de demo além de `jsdos`
- Alterações no repositório do assembly, que permanece intocado

## Decisões e justificativas

| Decisão | Escolha | Por quê |
|---|---|---|
| Backend do emulador | **DOSBox simples** (`wdosbox`) | 1,4 MB contra 7,5 MB do DOSBox-X, e o jogo foi comprovadamente executado no DOSBox comum. O DOSBox-X existe para Windows 9x e 3Dfx, nada que este jogo use |
| Origem do js-dos | **Dependência npm, copiada no build** | Serve da nossa origem, preservando a regra de zero requisições a terceiros da Fase 1, sem commitar 1,7 MB de binário no git |
| Bundle do jogo | **Versionado**, com `rake game:build` | São 2,1 KB que quase nunca mudam. Versionar mantém o CI trivial: o deploy não precisa de Docker, só quem mexe no assembly roda o rebuild |
| Carregamento | **Sob clique**, não automático | ~1,7 MB só descem quando o visitante pede. Quem veio ler sobre o projeto não paga a conta do emulador |
| Repositório do jogo | **Referenciado por URL**, não submodule | Continua um projeto independente; o site consome o artefato, não o fonte |

## Arquitetura

### Estrutura de arquivos

```
viniciuscole.dev/
├── package.json                      # + dependencia js-dos
├── Rakefile                          # + tasks game:build e jsdos:vendor
├── .gitignore                        # + src/vendor/
├── build/
│   └── game/
│       ├── Dockerfile                # nasm + Open Watcom wlink
│       └── dosbox.conf               # config embutida no bundle
├── src/
│   ├── demos/
│   │   └── tic-tac-toe/
│   │       └── vca.jsdos             # VERSIONADO, 2,1 KB
│   ├── vendor/                       # GITIGNORADO, preenchido no build
│   │   └── js-dos/
│   │       ├── js-dos.js
│   │       ├── js-dos.css
│   │       └── emulators/wdosbox.{js,wasm}
│   ├── _partials/demos/
│   │   ├── _none.erb                 # ja existe
│   │   └── _jsdos.erb                # NOVO
│   └── _projects/tic-tac-toe.{en,pt}.md   # demo.type: none -> jsdos
├── frontend/
│   ├── javascript/jsdos-player.js    # NOVO: boot sob clique + teclado na tela
│   └── styles/crt.css                # NOVO: tratamento CRT
└── test/jsdos_test.rb                # NOVO
```

### O partial `demos/_jsdos.erb`

Único arquivo que o dispatcher precisa para o tipo `jsdos` existir — a Fase 1 já
registrou `jsdos` em `Builders::DemoHelper::DEMO_TYPES` e o layout de projeto já
chama `demo_partial_for(resource)`. **Nenhum arquivo existente muda para a demo
passar a existir**, exceto o front matter do próprio projeto.

O partial emite:

- Uma moldura com o botão de iniciar e o resumo do que vai carregar (tamanho e
  que é um emulador), para o clique ser informado
- O contêiner do emulador, vazio até o clique
- O painel de comandos, com as chaves de tradução
- O teclado na tela
- O aviso de licença

O caminho do bundle vem do front matter (`demo.bundle`), com o mesmo tratamento
defensivo que a Fase 1 aplicou ao `demo.type`: ausência ou formato inesperado
degrada para uma mensagem, nunca derruba o build.

### Front matter do projeto

```yaml
demo:
  type: jsdos
  bundle: /demos/tic-tac-toe/vca.jsdos
```

### Carregamento sob clique

`frontend/javascript/jsdos-player.js` não faz nada até o clique. No clique:
carrega `js-dos.js` da nossa origem, instancia o player apontando para o bundle
e para `emulators/`, e troca a moldura pelo emulador.

Se o carregamento falhar — rede caindo, WebAssembly bloqueado, arquivo ausente —
a moldura mostra uma mensagem traduzida com link para o repositório do jogo, em
vez de um retângulo preto sem explicação.

### Teclado na tela

Componente separado do player, com uma responsabilidade: traduzir cliques em
teclas. Grade 3×3 para a posição, botões para X, círculo, reiniciar (`c`) e sair
(`s`). Uma jogada é a sequência `X` + linha + coluna + Enter.

**Risco conhecido e não resolvido nesta spec:** a API exata do js-dos 8.4.1 para
injetar teclas não foi verificada. A primeira tarefa da implementação verifica
qual mecanismo funciona — a interface de comandos do próprio js-dos, ou eventos
de teclado sintéticos despachados ao canvas — e o resultado é registrado antes
de o componente ser construído. Não inventar a API: descobrir e comprovar.

### Fluxo de build

```
rake check / CI
   ├─ jsdos:vendor        copia js-dos do node_modules para src/vendor/
   ├─ frontend:build      esbuild (ja existe)
   ├─ bin/bridgetown build  copia src/vendor e src/demos para output/
   ├─ minitest
   └─ html-proofer
```

`rake game:build` é separado e manual: reconstrói `vca.jsdos` a partir do fonte
do assembly via container. Não entra no `check` — exigiria Docker em toda
execução para regenerar um artefato que quase nunca muda.

## Tratamento de erros

| Situação | Comportamento |
|---|---|
| `demo.bundle` ausente ou malformado | Moldura mostra mensagem traduzida, build não quebra |
| Falha ao carregar js-dos ou o wasm | Mensagem traduzida com link para o repositório |
| WebAssembly indisponível no browser | Mesma mensagem; o site continua navegável |
| `src/vendor/js-dos` não preenchido | `rake check` falha alto no teste de assets, como já acontece com o esbuild |
| Bundle `.jsdos` corrompido | Teste verifica que é zip válido contendo `VCA.EXE` |

## Testes

Executados por `rake check`, que a Fase 1 já ligou a build de frontend, site,
minitest e html-proofer.

1. **Bundle íntegro** — `src/demos/tic-tac-toe/vca.jsdos` existe, é um zip
   válido, e contém `VCA.EXE` e a configuração do DOSBox.
2. **Dispatcher liga o tipo certo** — a página do projeto renderiza o partial
   `jsdos` e não o placeholder `none`, nos dois idiomas.
3. **Assets do emulador na saída** — `js-dos.js`, `js-dos.css` e
   `wdosbox.wasm` presentes em `output/vendor/js-dos/`, e o bundle em
   `output/demos/`.
4. **Zero requisições a terceiros continua valendo** — o teste da Fase 1 segue
   verde com o emulador na página; nada aponta para CDN.
5. **Textos traduzidos** — botão de iniciar, painel de comandos, rótulos do
   teclado e mensagens de erro têm chave nos dois arquivos de locale, e o teste
   de paridade da Fase 1 continua verde.
6. **Comando documentado é `C`** — o painel de instruções renderizado contém a
   sintaxe correta do círculo. Guarda contra alguém "corrigir" para `O` seguindo
   o readme do repositório do jogo.

**O que não é testado automatizado, e por quê:** o emulador efetivamente
executando o jogo. Isso exige um navegador headless que a máquina de
desenvolvimento não tem — instalar o Chrome para Playwright pede sudo com senha.
A verificação equivalente foi feita à mão durante o design, e a spec registra
isso em vez de fingir cobertura. Se um navegador headless ficar disponível, o
teste natural é: carregar a página, clicar em iniciar, enviar `X11`, e comparar
o canvas com uma imagem de referência.

## Visual

A página do jogo é a única do site que vai fundo no retrô, usando os tokens VGA
que a Fase 1 já definiu: moldura de monitor, fósforo, leve vinheta. O restante
do site permanece moderno e limpo, o que faz o CRT parecer intencional em vez de
tema aplicado por cima de tudo.

O emulador mantém a proporção do modo VGA 12h (640×480, 4:3). Em telas
estreitas, o teclado na tela fica abaixo do emulador; em telas largas, ao lado.

`prefers-reduced-motion` desliga qualquer animação da moldura.

## Licenciamento

js-dos é **GPL-2.0**, e o DOSBox que ele embute também. Servir esses arquivos é
distribuição, então a página do jogo traz o aviso de licença e um link para o
fonte upstream.

Isso não afeta a licença do site: carregar uma biblioteca GPL numa página é
agregação, não obra derivada. O código do site — ERB, CSS, Ruby — permanece
nosso e separado.

## Critérios de sucesso

- A página do projeto tem o jogo jogável, carregado sob clique
- Jogar uma partida completa funciona no desktop pelo teclado e no celular pelo
  teclado na tela
- Adicionar a demo não exigiu alterar nenhum arquivo existente além do front
  matter do projeto — a promessa da Fase 1 se confirma na prática
- `rake check` verde, incluindo html-proofer
- Nenhuma requisição a terceiros na página publicada
