# viniciuscole.dev

Site pessoal, gerado com [Bridgetown](https://www.bridgetownrb.com) e publicado
no Cloudflare Pages.

## Pré-requisitos

- Ruby 3.4.9 (veja `.ruby-version`)
- Node 22 (veja `.nvmrc`) — obrigatório: o `config/esbuild.defaults.js` usa
  `fs.globSync`, disponível apenas a partir do Node 22. Com Node 20 o
  frontend não compila e o site publica com `MISSING_ESBUILD_ASSET` no lugar
  do CSS e do JavaScript.

## Rodar localmente

    bundle install
    npm install
    bundle exec rake jsdos:vendor
    bin/bridgetown start

O `rake jsdos:vendor` copia o js-dos do `node_modules/` para `src/vendor/`,
que é gitignorado e nasce vazio. Sem essa etapa a página do jogo sobe com a
moldura, mas o clique em **Jogar** dá 404 no emulador — o `rake check` roda a
task sozinho, o `bin/bridgetown start` não.

## Verificar antes de publicar

    bundle exec rake check

Limpa o `output/`, constrói o frontend com esbuild, constrói o site, roda a
suíte de testes (minitest) e por fim verifica links internos e imagens no HTML
gerado com html-proofer.

A limpeza é parte da verificação, não zelo: sem ela, uma página renomeada ou
removida deixa o arquivo antigo em `output/`, e os testes e o html-proofer
seguem aprovando HTML que o build atual não produz mais.

## Adicionar um projeto

Crie dois arquivos Markdown: `src/_projects/<slug>.en.md` e
`src/_projects/<slug>.pt.md`. Os dois idiomas são obrigatórios — a suíte
reprova um projeto que exista em apenas um.

Campos obrigatórios no front matter: `title`, `locale`, `slug`, `summary`,
`tech`. Esses cinco, e nada mais — não escreva `layout:`. O layout da coleção
vem do bloco `defaults` em `config/initializers.rb`; a suíte reprova um
projeto que declare `layout` no front matter, justamente para o default
continuar sendo exercitado de verdade.

Campos opcionais: `year`, `featured`, `order`, `repo`, `demo`.

O `summary` não é só o texto do card: ele também vira a `meta description` e o
`og:description` da página do projeto.

Para embutir uma demo, defina `demo.type` com um dos tipos registrados em
`plugins/builders/demo_helper.rb` (`DEMO_TYPES`) e crie o partial
correspondente em `src/_partials/demos/`, por exemplo `_jsdos.erb` para o
tipo `jsdos`. Um `demo.type` desconhecido, ausente, ou com front matter mal
formado (ex.: `demo: jsdos` em vez de `demo:\n  type: jsdos`) nunca derruba o
build: o helper degrada para o partial `demos/none`.

## Tarefas do emulador e do jogo

    bundle exec rake jsdos:vendor

Copia da dependência npm `js-dos` para `src/vendor/js-dos/` tudo que o
emulador busca em tempo de execução: `js-dos.js`, `emulators/emulators.js`,
o backend `wdosbox.{js,wasm}`, o `wlibzip.{js,wasm}` que lê o bundle `.jsdos`
e o texto da GPL-2.0. Servir da nossa origem é o que mantém a regra de zero
requisições a terceiros. O `js-dos.css` **não** é copiado de propósito: ele
abre com o Preflight do Tailwind e reestilizaria o site inteiro; as poucas
regras que o modo kiosk usa vivem em `frontend/styles/crt.css`, escopadas em
`.demo-screen`.

    bundle exec rake game:build

Reconstrói `src/demos/tic-tac-toe/vca.jsdos` a partir do fonte em assembly,
num container (NASM + Open Watcom `wlink`). Exige Docker, baixa ~143 MB e é
manual de propósito: o bundle tem 2,1 KB, é versionado e quase nunca muda,
então nem o `check` nem o deploy precisam de Docker. Só quem mexe no assembly
roda isto.

    bundle exec rake demo2d:build

Reconstrói o jogo 2D em WebAssembly (`src/demos/2d-graphics/jogo.{js,wasm,data}`,
~380 KB somados) a partir do fonte em C++/OpenGL de
`github.com/viniciuscole/2D-Computer-Graphics`, clonado num SHA fixo — não
`main` — porque um upstream que andasse faria os patches aplicarem torto em
silêncio, trocando um erro de build por um `.wasm` que aborta no primeiro
quadro. Os três patches em `build/2d/*.patch` aplicam nessa ordem: `0001`
troca `GL_POLYGON` por `GL_TRIANGLE_FAN` (a emulação de modo imediato do
Emscripten não tem o primeiro); `0002` tira do C++ o desenho de texto do GLUT
e o reinício por tecla, levando os dois para HTML/JavaScript; `0003`
acrescenta W como atalho de pulo e neutraliza o ESC que antes encerrava o
jogo. Exige Docker. Os artefatos gerados são versionados de propósito — quem
clona o site não precisa de Docker para rodá-lo — então só quem mexe nos
patches, no SHA ou no `build.sh` roda isto.

    bundle exec rake demo2d:verify
    bundle exec rake demo2d:verify:site

Os dois rodam o mesmo `build/2d/verify.js` num Chromium de verdade (via
Playwright, imagem `mcr.microsoft.com/playwright`), porque nenhum teste
estático pega uma regressão de runtime do OpenGL emulado — a primeira
compilação deste port linkou limpa e abortava no primeiro quadro. `verify`
sobe uma bancada mínima (`build/2d/bench.html`) que serve os artefatos de um
diretório plano; `verify:site` sobe a página real a partir de `output/`
(rode `bin/bridgetown build` antes) e é o único capaz de pegar um
descompasso de caminho entre página e bundle — em produção eles moram em
diretórios diferentes (`/projects/...` e `/demos/...`), e a bancada, sendo
plana, não reproduz essa classe de defeito. Os dois exigem Docker.

## Textos, metadados e tema

Toda string de interface passa por `<%= t("chave") %>`, com a chave presente
nos **dois** arquivos de `src/_locales/` (`en.yml` e `pt.yml`). Um teste de
paridade reprova o CI quando os conjuntos de chaves divergem. Isso vale
também para as páginas de erro (`src/404.html`, `src/500.html`).

Título, tagline e descrição do site também são chaves de locale
(`site.title`, `site.tagline`, `site.description`), e é delas que saem o
`<title>`, a `meta description` e as tags Open Graph. Não existe
`site_metadata.yml`: um arquivo só, sem idioma, publicaria a página em
português com título e descrição em inglês.

Os links de contato ficam em `src/_data/site_links.yml`, fonte única do
footer.

`config/initializers.rb` ainda tem `url ""` porque o domínio não foi
registrado. Enquanto estiver vazio, `canonical` e `og:url` saem como caminhos
relativos; preencher `url` os torna absolutos sem mexer em nenhum template.

O tema segue o `prefers-color-scheme` do sistema. O botão do header persiste a
escolha manual em `localStorage`, e só o clique persiste — o carregamento da
página nunca grava nada, senão o tema do primeiro acesso ficaria congelado
para sempre. Um script inline e bloqueante no `<head>` aplica o tema salvo
antes do primeiro paint, para não piscar branco.

## Configuração

Toda a configuração do site vive em `config/initializers.rb`. O Bridgetown 2
não usa `bridgetown.config.yml` — não crie esse arquivo.

Duas armadilhas de permalink aprendidas neste projeto, na prática:

- A coleção `projects`, em `config/initializers.rb`, precisa manter
  `permalink "simple"`. Uma string de permalink customizada ignora o prefixo
  de idioma e faz as duas traduções (`.en.md` e `.pt.md`) gravarem no mesmo
  arquivo de saída, uma sobrescrevendo a outra silenciosamente.
- Nenhuma página deve usar `permalink: /` literal no front matter. No
  Bridgetown 2.2.2 isso faz `relative_url` resolver para `"//"` em vez de
  `"/"`, quebrando todo link de volta para essa página. Para a home, deixe o
  permalink padrão da coleção `pages` (`/:locale/:path/`) resolver sozinho —
  ele já produz `/` corretamente.

## CI e deploy

Todo push na branch `main` builda o site e o publica no Cloudflare Pages
(projeto `viniciuscole-dev`, modo Direct Upload); todo pull request roda
apenas a suíte de verificação, sem publicar. Veja
`.github/workflows/ci.yml`.

Para o deploy funcionar, o repositório no GitHub precisa ter os segredos
`CLOUDFLARE_API_TOKEN` (permissão `Cloudflare Pages: Edit`) e
`CLOUDFLARE_ACCOUNT_ID`, cadastrados em **Settings → Secrets and variables →
Actions**.
