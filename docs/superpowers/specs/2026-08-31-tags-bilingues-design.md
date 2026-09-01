# Tags bilíngues para os posts

**Data:** 2026-08-31
**Status:** aprovado para implementação
**Specs anteriores:**
`docs/superpowers/specs/2026-08-16-viniciuscole-dev-site-design.md` (Fase 1)

**Depende de:** o post inaugural existir nos dois idiomas
(branch `worktree-post-pt-traducao`, PR #6). Sem posts em português, `/pt/tags/`
nasceria vazio e o pareamento bilíngue — que é o coração desta spec — não teria
como ser exercido nem testado.

## Objetivo

Classificar posts por assunto, com **múltiplas tags por post**, e gerar uma
página por tag em cada idioma. As páginas de tag dos dois idiomas devem se
parear, de forma que o alternador de idioma funcione dentro delas como funciona
em qualquer outra página do site.

## `tags` não é `slug`

As duas convivem no mesmo front matter e é fácil confundi-las. A distinção é a
base de todo o resto:

| | `slug` | `tags` |
|---|---|---|
| cardinalidade | um valor por post | vários valores por post |
| o que agrupa | **o mesmo post** em locales diferentes | **posts diferentes** sobre o mesmo assunto |
| papel | chave primária / identidade | índice secundário / classificação |

Elas não competem. Um post tem exatamente um `slug` e quantas `tags` quiser.

Há uma reviravolta que dá simetria ao desenho, detalhada abaixo: na **página de
tag**, a chave canônica da tag é o `slug` dela. O mesmo mecanismo, uma camada
acima.

## O que já foi verificado no código do framework

Nada aqui é suposição sobre o que o Bridgetown 2.2.2 faz; tudo foi lido no
código do gem instalado antes desta spec ser escrita.

### Tags já são taxonomia nativa

`bridgetown-core/configuration.rb` traz, nos defaults:

```ruby
"taxonomies" => {
  category: { key: "categories", title: "Category" },
  tag:      { key: "tags",       title: "Tag" },
},
```

Ou seja, `tags: [a, b, c]` no front matter **já é lido** sem nenhuma configuração
nossa, e `resource.taxonomies` já expõe os termos. Múltiplas tags por post não
exige código: é o formato nativo.

### O gerador nativo de páginas por termo **não serve** aqui

`Bridgetown::PrototypeGenerator` é o mecanismo do framework para gerar uma
página por termo, e era o candidato óbvio. Ler o código descartou-o, por dois
motivos independentes:

1. **Exige paginação global.** `ensure_pagination_enabled` avisa que
   "Pagination must be enabled for prototype pages to contain matches", e a
   busca de termos é feita por `Bridgetown::Paginate::PaginationIndexer`.
   Hoje `pagination` está desligado no `initializers.rb`; ligá-lo mudaria o
   comportamento do site inteiro para servir uma feature só.
2. **Não sabe o que é locale.** O `slugify_term` monta a URL como
   `"/#{@dir}/#{term_slug}/"`, sem prefixo de idioma nenhum. Ele foi escrito
   para site monolíngue.

O custo de contornar os dois é maior que o de gerar as páginas nós mesmos com o
padrão `SiteBuilder` que o repositório já usa.

### Páginas geradas **sabem** se parear — e é isso que resolve o problema

`GeneratedPage` inclui o concern `Localizable`. Em
`bridgetown-core/concerns/localizable.rb`, o pareamento é:

```ruby
def matches_resource?(item)
  if item.relative_path.is_a?(String)
    item.localeless_path == localeless_path
  else
    item.relative_path.parent == relative_path.parent
  end && item.data.slug == data.slug
end

def localeless_path
  relative_path.gsub(%r{\A#{data.locale}/}, "")
end
```

Duas páginas geradas se pareiam quando o caminho **sem o prefixo de locale**
coincide **e** o `slug` coincide. Logo, se gerarmos as páginas de tag com

- `data.slug` = a chave canônica da tag, e
- `relative_path` = `tags/<tag>.html` em inglês e `pt/tags/<tag>.html` em
  português,

o `localeless_path` das duas é `tags/<tag>.html` e o `slug` é o mesmo — elas se
pareiam sozinhas. **O `_partials/_locale_switcher.erb` funciona dentro das
páginas de tag sem uma linha de alteração**, porque ele já chama
`resource.all_locales`.

Além disso, `find_matching_locales` usa `site.generated_pages` como conjunto de
busca quando o item não responde a `collection` — que é exatamente o caso das
páginas geradas por um builder.

## Decisões

### Chave canônica, rótulo traduzido

Os dois arquivos de um post levam a **mesma** lista, em chaves canônicas:

```yaml
tags: [discrete-math, proofs]
```

O nome exibido sai de `src/_locales/{pt,en}.yml`, sob a chave `tags:`:

```yaml
en:
  tags:
    discrete-math: "Discrete math"
pt:
  tags:
    discrete-math: "Matemática discreta"
```

Foram consideradas e descartadas duas alternativas:

- **Tags livres por idioma** (`matemática-discreta` em PT, `discrete-math` em
  EN). Mais rápido de escrever, mas `/tags/` e `/pt/tags/` viram universos
  disjuntos, o alternador de idioma quebra dentro de toda página de tag, e nada
  impede `provas` e `demonstracoes` virarem duas tags para o mesmo assunto.
- **Slug de URL traduzido** (`/pt/tags/matematica-discreta/`). URL mais bonita em
  português, mas exige uma tabela de tradução de slug por tag e contraria a
  convenção que o site já segue.

A convenção escolhida é a que o site **já pratica**: as URLs em português já
carregam segmentos em inglês — `/pt/blog/`, `/pt/projects/`,
`/pt/projects/tic-tac-toe/`. Só o texto visível é traduzido. E é a única das três
em que "múltiplas tags por post" não multiplica trabalho de tradução: a lista é
escrita uma vez e serve os dois idiomas.

### Só se gera tag que tem post naquele idioma

A varredura é por locale. Uma tag usada apenas por um post em inglês não gera
`/pt/tags/<tag>/`. Isso evita página vazia e evita que o alternador ofereça uma
tradução que não existe — nesse caso ele cai no comportamento que já tem,
mandando para a home do outro idioma.

### Rótulo ausente degrada, não derruba

Tag em uso sem rótulo cadastrado emite `Bridgetown.logger.warn` e exibe a chave
crua. É a mesma postura de `Builders::DemoHelper.partial_for` diante de um tipo
de demo desconhecido: front matter malformado nunca derruba o build.

A rede de segurança contra o rótulo esquecido é de teste, não de build (abaixo).

## Arquitetura

| arquivo | papel |
|---|---|
| `plugins/builders/tag_pages.rb` (novo) | varre os posts por locale, gera as páginas de tag e os índices |
| `src/_layouts/tag.erb` (novo) | página de uma tag: título traduzido + posts daquela tag naquele idioma |
| `src/_partials/_tag_list.erb` (novo) | os chips de tag de um post, reutilizado pelo layout de post |
| `src/_layouts/post.erb` | passa a exibir as tags do post |
| `src/_locales/{pt,en}.yml` | rótulos das tags + strings das páginas de tag |
| `src/_posts/*.md` | os dois arquivos do post inaugural ganham tags reais |
| `test/tags_test.rb` (novo) | as guardas descritas abaixo |

URLs geradas:

```
/tags/                  /pt/tags/                 índice de todas as tags
/tags/<tag>/            /pt/tags/<tag>/           posts de uma tag
```

## Testes

O `rake check` já roda build limpo, minitest e html-proofer; todo link novo
passa a ser validado de graça pelo proofer.

1. **Índice existe nos dois locales**, e lista as tags em uso.
2. **Página de tag existe nos dois locales**, com o rótulo traduzido correto —
   "Matemática discreta" em `/pt/tags/discrete-math/`, "Discrete math" em
   `/tags/discrete-math/`.
3. **O alternador de idioma pareia as duas**, nos dois sentidos. Esta é a guarda
   central: é a propriedade que motivou a escolha de `slug` = chave da tag, e a
   que quebraria em silêncio se o mecanismo de `localeless_path` mudasse.
4. **Múltiplas tags por post.** Um post com N tags aparece na página de todas as
   N, e as N aparecem no corpo do post. Requisito explícito, então tem teste
   explícito.
5. **Toda tag em uso tem rótulo nos dois idiomas.** O `locales_test` já cobra
   conjuntos de chave idênticos entre `en.yml` e `pt.yml`, mas paridade não pega
   este caso: uma tag ausente nos **dois** arquivos é simétrica e passaria. Este
   teste cobre a cobertura, não a simetria.
6. **Rótulo ausente degrada sem quebrar**: exibe a chave crua, o build passa.

## Fora de escopo

- **Séries ordenadas.** Foi decidido que tags substituem a ideia de série. Um
  arco ordenado, com navegação "próximo/anterior", é um mecanismo diferente
  (tag é conjunto sem ordem) e não será construído agora. Nada aqui impede
  acrescentá-lo depois: uma chave `series` seria aditiva.
- Nuvem de tags, contagem de posts na navegação, feed por tag.
- Tags em `_projects`. A taxonomia é nativa e funcionaria, mas projetos já têm
  `tech:` cumprindo esse papel.
