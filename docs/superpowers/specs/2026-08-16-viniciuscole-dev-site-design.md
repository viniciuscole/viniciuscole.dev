# viniciuscole.dev — Site pessoal (Fase 1)

**Data:** 2026-08-16
**Status:** aprovado para planejamento
**Fase:** 1 de 2 (a demo emulada do jogo é a Fase 2, com spec própria)

## Objetivo

Um site pessoal em `viniciuscole.dev` que apresenta o Vinicius e reúne seus
projetos, construído de modo que **adicionar um projeto novo seja escrever um
arquivo Markdown**, não codificar uma página.

O primeiro projeto a entrar é o
[tic-tac-toe-assembly](https://github.com/viniciuscole/tic-tac-toe-assembly),
um jogo da velha em assembly x86 de 16 bits para DOS. Na Fase 1 ele aparece
como página de projeto (descrição, tecnologias, link do repositório). Na Fase 2
ganha a demo jogável, emulada no browser.

## Escopo

**Dentro da Fase 1:**

- Home com apresentação, projetos em destaque, posts recentes e links de contato
- Coleção de projetos com página individual por projeto
- Blog em Markdown
- Bilíngue inglês/português
- Ponto de extensão para demos embutidas (o mecanismo, com um tipo: `none`)
- Deploy automatizado e domínio no ar com HTTPS

**Fora da Fase 1 (Fase 2):**

- Emulação do jogo via js-dos, empacotamento `.jsdos`, build do `.exe` no CI,
  estilo CRT da página do jogo

**Fora de escopo (não planejado):**

- Analytics, newsletter, comentários, busca, feed RSS, seção de currículo,
  qualquer backend ou banco de dados

## Decisões e justificativas

| Decisão | Escolha | Por quê |
|---|---|---|
| Gerador | Bridgetown 2.2.2 | Ruby e ERB, terreno conhecido para quem trabalha com Rails; i18n pela **mesma gem I18n do Rails**; gera estático puro |
| Por que não Rails | — | Não há banco, autenticação nem estado no servidor. Rails custaria um servidor 24/7 (~US$5-7/mês) para servir HTML parado |
| Ruby | 3.4.9 | Já instalado na máquina; Bridgetown 2 exige 3.1+ |
| CSS | CSS moderno com custom properties, sem framework | O design é autoral (acento retrô); um framework utilitário atrapalharia mais do que ajudaria |
| Hospedagem | Cloudflare Pages | Estático grátis, HTTPS automático, e Pages Functions disponível no dia em que um projeto precisar de backend — sem migração |
| Build | GitHub Actions → deploy via `wrangler` | Constrói com a **nossa** versão de Ruby. Se o Pages construísse direto do repo, ficaríamos reféns da versão de Ruby da imagem deles |
| Domínio | Cloudflare Registrar | Preço de custo (~US$12/ano em `.dev`) e mesmo painel da hospedagem, sem configurar DNS na mão |

**Restrição do TLD:** `.dev` está na lista HSTS preload dos browsers. HTTPS não é
opcional — o site é inacessível por HTTP puro. O Cloudflare Pages já emite e
renova o certificado automaticamente, então isso é uma restrição satisfeita, não
uma tarefa.

**Disponibilidade do domínio:** consultas DNS em 2026-08-16 retornaram NXDOMAIN
sem registros NS na zona `.dev`, indicando que `viniciuscole.dev` está livre.
Confirmar no registrador antes de depender disso.

## Arquitetura

### Repositórios

O repositório `tic-tac-toe-assembly` **permanece intocado**. É um projeto
independente e não deve virar apêndice do site. O site o referencia por URL na
Fase 1; a Fase 2 decidirá como consumir o fonte para gerar o executável.

### Estrutura de diretórios

```
viniciuscole.dev/
├── bridgetown.config.yml       # locales, coleções, permalinks
├── config/initializers.rb
├── Gemfile
├── package.json                # esbuild (bundler de assets do Bridgetown)
├── .ruby-version               # 3.4.9
├── plugins/
│   └── demo_helper.rb          # tipos de demo permitidos + resolução
├── frontend/
│   ├── javascript/index.js     # JS mínimo: alternador de tema
│   └── styles/
│       ├── index.css
│       ├── _tokens.css         # cores, tipografia, espaçamento
│       ├── _base.css
│       └── _components.css
├── src/
│   ├── _data/
│   │   └── site_links.yml      # GitHub, LinkedIn, e-mail
│   ├── _locales/
│   │   ├── en.yml              # strings de interface
│   │   └── pt.yml
│   ├── _layouts/
│   │   ├── default.erb         # shell: head, header, footer
│   │   ├── page.erb
│   │   ├── post.erb
│   │   └── project.erb
│   ├── _partials/
│   │   ├── _header.erb
│   │   ├── _footer.erb
│   │   ├── _locale_switcher.erb
│   │   ├── _project_card.erb
│   │   └── demos/
│   │       ├── _dispatcher.erb # escolhe o embed pelo tipo
│   │       └── _none.erb       # projeto sem demo
│   ├── _projects/
│   │   ├── tic-tac-toe.en.md
│   │   └── tic-tac-toe.pt.md
│   ├── _posts/
│   ├── index.en.md
│   ├── index.pt.md
│   ├── projects.en.md          # listagem
│   ├── projects.pt.md
│   ├── blog.en.md
│   └── blog.pt.md
├── docs/superpowers/specs/
└── .github/workflows/ci.yml
```

### Componentes

Cada componente abaixo tem uma responsabilidade e uma interface declarada.

**`default.erb` (layout raiz)**
Renderiza o shell HTML: `<head>` com meta tags e Open Graph, header com
navegação e alternador de idioma, footer. Todo o resto é conteúdo injetado.
Depende de: `_header`, `_footer`, `_locales`.

**Coleção `projects`**
Fonte única de verdade sobre os projetos. Configurada em
`bridgetown.config.yml` com `output: true` e
`permalink: /projects/:slug/`. Consumida pela home (destaques), pela listagem e
pelo layout de projeto.

**`_project_card.erb`**
Recebe um recurso de projeto, devolve o card da listagem (título, resumo, tags
de tecnologia, ano). Usado pela home e pela listagem — um único lugar para
mudar a aparência de um projeto resumido.

**`demos/_dispatcher.erb`** — o ponto de extensão que dá nome ao pedido
Lê `resource.data.demo.type` e delega ao partial correspondente. Adicionar um
tipo de demo no futuro é criar `demos/_<tipo>.erb` e registrá-lo na lista de
tipos permitidos, sem tocar em `project.erb` nem em nenhum outro arquivo.

A lista de tipos permitidos e a resolução vivem num helper Ruby,
`plugins/demo_helper.rb`, que expõe `demo_partial_for(resource)`:

```ruby
DEMO_TYPES = %w[none jsdos].freeze

def demo_partial_for(resource)
  type = resource.data.dig(:demo, :type) || "none"
  return "demos/#{type}" if DEMO_TYPES.include?(type)

  Bridgetown.logger.warn "Demo", "tipo desconhecido #{type.inspect} em #{resource.relative_path}"
  "demos/none"
end
```

Um tipo fora da lista renderiza `_none.erb` e emite aviso no build — o site
nunca quebra por causa de um erro de digitação no front matter, mas o erro fica
visível.

Na Fase 1 apenas `none` existe como partial; `jsdos` já consta na lista e é
implementado na Fase 2.

**`src/_data/site_links.yml`**
Fonte única dos links de contato (GitHub, LinkedIn, e-mail). Consumida pelo
footer e pela seção de contato da home, para que um link mude num lugar só.

**`_locale_switcher.erb`**
Usa `resource.all_locales` para montar os links entre traduções. Quando a
tradução do recurso atual não existe, aponta para a página inicial daquele
idioma em vez de gerar um link quebrado.

### Modelo de conteúdo

Front matter de um projeto (schema fixo):

```yaml
---
title: Tic-Tac-Toe in x86 Assembly
locale: en
slug: tic-tac-toe        # idêntico entre idiomas — é o que pareia as traduções
year: 2019
featured: true           # aparece na home
order: 1                 # ordem na listagem, menor primeiro
summary: >
  Resumo de uma linha, usado no card e nas meta tags.
tech: [x86 Assembly, NASM, DOS, VGA]
repo: https://github.com/viniciuscole/tic-tac-toe-assembly
demo:
  type: none             # none | jsdos
---

Corpo em Markdown: a descrição longa do projeto.
```

Campos obrigatórios: `title`, `locale`, `slug`, `summary`, `tech`.
Campos opcionais: `year`, `featured` (padrão `false`), `order` (padrão `999`),
`repo`, `demo` (padrão `{type: none}`).

**Adicionar um projeto futuro** = criar `src/_projects/<slug>.en.md` e
`<slug>.pt.md`. Nada mais.

### Internacionalização

```yaml
available_locales: [en, pt]
default_locale: en
prefix_default_locale: false
```

Rotas resultantes:

| Conteúdo | Inglês | Português |
|---|---|---|
| Home | `/` | `/pt/` |
| Listagem de projetos | `/projects/` | `/pt/projects/` |
| Projeto | `/projects/tic-tac-toe/` | `/pt/projects/tic-tac-toe/` |
| Blog | `/blog/` | `/pt/blog/` |

O segmento de caminho (`projects`, `blog`) permanece em inglês nos dois idiomas.
Traduzi-lo exigiria `locale_overrides` de permalink em cada recurso, o que
multiplica a chance de link quebrado sem ganho real. Fica registrado como
refinamento possível, não como pendência.

Strings de interface ficam em `src/_locales/{en,pt}.yml` e são acessadas com
`<%= t("chave") %>`. Conteúdo (posts, projetos) fica em arquivos por idioma com
sufixo de locale.

**Regra de paridade:** todo **projeto** existe obrigatoriamente nos dois idiomas
— a listagem de projetos precisa estar completa em ambos. Um **post**, por outro
lado, pode existir em um só idioma; isso é esperado, e o alternador de idioma
trata o caso apontando para a listagem do blog naquele idioma.

## Fluxo de build e deploy

```
push na main
   └─> GitHub Actions
         ├─ bundle install (Ruby 3.4.9)
         ├─ npm ci
         ├─ bin/bridgetown build   ──> output/
         ├─ testes (abaixo)
         └─ wrangler pages deploy output/  ──> Cloudflare Pages
                                                └─> viniciuscole.dev (HTTPS)
```

Pull requests rodam build e testes, sem deploy.

Segredos necessários no repositório: `CLOUDFLARE_API_TOKEN` e
`CLOUDFLARE_ACCOUNT_ID`.

## Tratamento de erros

| Situação | Comportamento |
|---|---|
| Tipo de demo desconhecido no front matter | Renderiza `_none.erb`, registra aviso no build |
| Recurso sem tradução no outro idioma | Alternador aponta para a home daquele idioma |
| Chave de tradução ausente num dos `_locales/*.yml` | Teste de paridade de chaves falha o CI |
| Campo obrigatório ausente no front matter de projeto | Teste de validação falha o CI, apontando arquivo e campo |
| Link interno ou imagem quebrada | html-proofer falha o CI |

## Testes

Proporcionais ao risco real do projeto, executados por `rake test`:

1. **Build limpo** — `bin/bridgetown build` termina com código 0.
2. **Paridade de locales** — o conjunto de chaves de `en.yml` e `pt.yml` é
   idêntico; a diferença é reportada por chave.
3. **Validação de front matter** — todo recurso em `_projects` tem os campos
   obrigatórios, `demo.type` está em `DEMO_TYPES`, e todo `slug` de projeto tem
   exatamente um arquivo por idioma disponível (`.en.md` e `.pt.md`). Projeto em
   um idioma só reprova o CI; post em um idioma só é permitido.
4. **Estrutura de saída** — existem `output/index.html`, `output/pt/index.html`,
   `output/projects/tic-tac-toe/index.html` e a contraparte em `/pt/`.
5. **html-proofer** — sem links internos quebrados, todas as imagens com `alt`.

## Design visual

Base moderna e limpa, com acentos retrô contidos:

- **Tipografia** — corpo na pilha de fontes do sistema (zero bytes baixados);
  títulos e detalhes em monoespaçada auto-hospedada (JetBrains Mono, licença
  OFL). Sem requisições a terceiros.
- **Cores** — tokens em CSS custom properties. Acentos derivados da paleta VGA
  de 16 cores, o elo visual com o projeto em assembly.
- **Tema** — respeita `prefers-color-scheme`, com alternador manual persistido
  em `localStorage`. Esse é o único JavaScript do site na Fase 1.
- **Acessibilidade** — HTML semântico, estados de foco visíveis, contraste
  mínimo AA, navegação por teclado.

O tratamento CRT mais forte fica reservado à página do jogo, na Fase 2. Assim o
retrô parece intencional, e não um tema aplicado por cima de tudo.

## Critérios de sucesso da Fase 1

- `viniciuscole.dev` no ar com HTTPS válido
- Home, listagem de projetos, página do tic-tac-toe e blog funcionando nos dois
  idiomas, com alternador correto
- Adicionar um projeto novo requer apenas dois arquivos Markdown
- `rake test` verde, deploy automático a partir da `main`

## Anexo — verificação técnica já realizada (2026-08-16)

Registro do que foi comprovado na prática, para a Fase 2 não repetir o trabalho:

- Os dois arquivos do repositório do jogo (`vca.asm`, `draw.asm`) montam sem
  erros nem avisos com **NASM 2.16.01** usando `-f obj`, **sem nenhuma
  modificação no fonte**.
- A ligação com **Open Watcom `wlink` 2.0** (`format dos file vca.obj,draw.obj`)
  produz um executável DOS válido de 3.244 bytes: assinatura `MZ`, 7 páginas,
  3 parágrafos de cabeçalho, entrada em `CS:IP 0000:0000`, pilha em
  `SS:SP 0000:107c`.
- O toolchain roda em container `debian:bookworm-slim` com `nasm` do apt mais o
  `ow-snapshot.tar.xz` das releases do Open Watcom (~143 MB, do qual só
  `binl64/wlink` é necessário).
- Ainda **não** foi verificado: se o executável roda corretamente sob DOSBox e
  como se comporta o modo de vídeo VGA 12h dentro do js-dos. Essa é a primeira
  tarefa da Fase 2.
