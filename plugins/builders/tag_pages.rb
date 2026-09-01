class Builders::TagPages < SiteBuilder
  # Prefixo das chaves de rotulo em src/_locales/{en,pt}.yml.
  LABEL_SCOPE = "tags.label".freeze

  # Rotulo exibido de uma tag, no idioma pedido.
  #
  # Tag sem rotulo cadastrado nao derruba o build: emite warning e devolve a
  # chave crua, a mesma postura de Builders::DemoHelper.partial_for diante de
  # um tipo de demo desconhecido. A rede contra o rotulo esquecido e de teste
  # (test/tags_test.rb cobra rotulo nos dois idiomas para toda tag em uso),
  # nao de build -- um post novo nunca deve quebrar a publicacao do site
  # inteiro por causa de uma string de interface faltando.
  def self.label_for(tag, locale)
    label = I18n.t("#{LABEL_SCOPE}.#{tag}", locale: locale, default: nil)
    return label if label

    Bridgetown.logger.warn "Tags",
      "tag #{tag.inspect} sem rotulo em #{locale}, exibindo a chave crua"
    tag.to_s
  end

  # Tags de um resource, normalizadas. `tags` pode vir ausente, string unica
  # ou lista; qualquer uma das tres degrada para uma lista de strings.
  def self.tags_of(resource)
    Array(resource.data[:tags]).map { |tag| tag.to_s.strip }.reject(&:empty?)
  end

  def build
    generator :generate_tag_pages

    # Paginas geradas nao passam por Site#render_with_locale: o
    # `render_resources` do Bridgetown envolve cada resource na troca de
    # locale, mas `generated_pages.each(&:transform!)` roda logo depois, sem
    # nenhuma troca. Sem este hook, /pt/tags/<tag>/ renderizaria com o
    # I18n.locale que sobrou (o padrao, `en`) e sairia com a interface inteira
    # em ingles -- num site cujo proposito e ser bilingue.
    hook :generated_pages, :pre_render do |page|
      site.locale = page.data.locale if page.data.locale
    end

    # Devolve o locale ao padrao para nao vazar o do ultimo item renderizado.
    hook :generated_pages, :post_render do |_page|
      site.locale = site.config.default_locale
    end

    helper :tag_label do |tag|
      Builders::TagPages.label_for(tag, I18n.locale)
    end

    helper :tags_of do |resource|
      Builders::TagPages.tags_of(resource)
    end
  end

  def generate_tag_pages
    posts = site.collections.posts.resources

    site.config.available_locales.each do |locale|
      in_locale = posts.select { |post| post.data.locale.to_s == locale.to_s }
      tags = in_locale.flat_map { |post| self.class.tags_of(post) }.uniq.sort
      next if tags.empty?

      # Uma tag so ganha pagina no idioma em que ha post usando ela. Isso evita
      # pagina vazia e evita o alternador oferecer uma traducao inexistente --
      # nesse caso ele cai no fallback que ja tem, a home do outro idioma.
      tags.each { |tag| add_page(locale, "tags/#{tag}", "tag", slug: tag, tag: tag) }
      add_page(locale, "tags", "tag_index", slug: "index", tags: tags)
    end
  end

  private

  # Monta uma pagina gerada e a registra no site.
  #
  # O par (slug, caminho) e o que faz as versoes en e pt se parearem. O
  # concern Bridgetown::Localizable considera dois itens traducoes um do outro
  # quando o `slug` coincide e o caminho *sem o prefixo de locale* coincide
  # (`localeless_path`). Com slug = chave canonica da tag e caminhos
  # `tags/<tag>/index.html` e `pt/tags/<tag>/index.html`, os dois batem e o
  # _partials/_locale_switcher.erb funciona dentro das paginas de tag sem
  # alteracao nenhuma -- ele ja chama `resource.all_locales`.
  def add_page(locale, path, layout, slug:, **data)
    prefix = Builders::SiteHelpers.prefix_for(locale, site.config.default_locale)
    page = Bridgetown::GeneratedPage.new(site, site.source, "#{prefix}#{path}", "index.html")

    page.content = ""
    page.data.merge!(
      "layout" => layout,
      "locale" => locale.to_s,
      "slug"   => slug,
      "title"  => title_for(layout, locale, data[:tag]),
      **data.transform_keys(&:to_s)
    )

    site.add_generated_page(page)
  end

  # O <title> e as tags og: saem de `data.title`, montado aqui e nao no
  # template, porque nesta fase o I18n.locale ainda e o padrao -- traduzir
  # exige pedir o locale explicitamente.
  def title_for(layout, locale, tag)
    if layout == "tag_index"
      I18n.t("tags.index_title", locale: locale)
    else
      self.class.label_for(tag, locale)
    end
  end
end
