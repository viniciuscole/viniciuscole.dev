class Builders::SiteHelpers < SiteBuilder
  def build
    # Destino de fallback do alternador quando a traducao nao existe.
    # Ruling 1: quando `locale` vem nil/vazio (ex.: 404/500 sem front matter
    # `locale`), cai no idioma padrao em vez de produzir "//" (link quebrado).
    helper :locale_home_url do |locale|
      locale = site.config.default_locale if locale.to_s.empty?

      if locale.to_s == site.config.default_locale.to_s
        "/"
      else
        "/#{locale}/"
      end
    end

    # "" para o idioma padrao, "pt/" para os demais.
    # Mesmo fallback do helper acima, pelo mesmo motivo.
    helper :locale_prefix do |locale|
      locale = site.config.default_locale if locale.to_s.empty?

      if locale.to_s == site.config.default_locale.to_s
        ""
      else
        "#{locale}/"
      end
    end
  end
end
