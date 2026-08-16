# viniciuscole.dev

Site pessoal, gerado com [Bridgetown](https://www.bridgetownrb.com) e publicado
no Cloudflare Pages.

## Pré-requisitos

- Ruby 3.4.9 (veja `.ruby-version`)
- Node 22 (veja `.nvmrc`) — obrigatório: o `esbuild.config.js` usa
  `fs.globSync`, disponível apenas a partir do Node 22. Com Node 20 o
  frontend não compila e o site publica com `MISSING_ESBUILD_ASSET` no lugar
  do CSS e do JavaScript.

## Rodar localmente

    bundle install
    npm install
    bin/bridgetown start

## Verificar antes de publicar

    bundle exec rake check

Constrói o frontend com esbuild, constrói o site, roda a suíte de testes
(minitest) e por fim verifica links internos e imagens no HTML gerado com
html-proofer.

## Adicionar um projeto

Crie dois arquivos Markdown: `src/_projects/<slug>.en.md` e
`src/_projects/<slug>.pt.md`. Os dois idiomas são obrigatórios — a suíte
reprova um projeto que exista em apenas um.

Campos obrigatórios no front matter: `title`, `locale`, `slug`, `summary`,
`tech`.

Campos opcionais: `year`, `featured`, `order`, `repo`, `demo`.

Para embutir uma demo, defina `demo.type` com um dos tipos registrados em
`plugins/builders/demo_helper.rb` (`DEMO_TYPES`) e crie o partial
correspondente em `src/_partials/demos/`, por exemplo `_jsdos.erb` para o
tipo `jsdos`. Um `demo.type` desconhecido, ausente, ou com front matter mal
formado (ex.: `demo: jsdos` em vez de `demo:\n  type: jsdos`) nunca derruba o
build: o helper degrada para o partial `demos/none`.

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
