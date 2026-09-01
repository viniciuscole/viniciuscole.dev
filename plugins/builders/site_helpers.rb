class Builders::SiteHelpers < SiteBuilder
  # "" para o idioma padrao, "pt/" para os demais.
  #
  # Ruling 1: quando `locale` vem nil/vazio (ex.: 404/500 sem front matter
  # `locale`), cai no idioma padrao em vez de produzir "//" (link quebrado).
  #
  # Vive como metodo de classe porque tem dois consumidores: os helpers de
  # template abaixo e Builders::TagPages, que monta os caminhos das paginas de
  # tag geradas. Divergir entre os dois produziria uma URL de tag que o
  # alternador de idioma nao consegue parear -- e o pareamento depende do
  # caminho sem o prefixo de locale coincidir exatamente.
  def self.prefix_for(locale, default_locale)
    locale = default_locale if locale.to_s.empty?

    if locale.to_s == default_locale.to_s
      ""
    else
      "#{locale}/"
    end
  end

  def build
    # Destino de fallback do alternador quando a traducao nao existe.
    helper :locale_home_url do |locale|
      "/#{Builders::SiteHelpers.prefix_for(locale, site.config.default_locale)}"
    end

    helper :locale_prefix do |locale|
      Builders::SiteHelpers.prefix_for(locale, site.config.default_locale)
    end
  end
end
