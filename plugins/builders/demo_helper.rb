class Builders::DemoHelper < SiteBuilder
  # Tipos de demo suportados. Acrescentar um tipo aqui e criar o partial
  # correspondente em src/_partials/demos/_<tipo>.erb e tudo que e preciso
  # para um projeto novo embutir uma demo.
  DEMO_TYPES = %w[none jsdos wasm video].freeze

  def build
    helper :demo_partial_for do |resource|
      Builders::DemoHelper.partial_for(resource)
    end
  end

  # Determina o partial de demo para um resource. Front matter malformado
  # nunca pode derrubar o build: `demo` pode estar ausente, pode ser um mapa
  # sem `type`, ou pode ser um valor escalar (ex.: `demo: jsdos` em vez de
  # `demo:\n  type: jsdos`) em vez do mapa aninhado esperado. Em qualquer um
  # desses casos o resultado degrada para o placeholder "none".
  def self.partial_for(resource)
    demo = resource.data[:demo]
    type = (demo.is_a?(Hash) ? demo[:type] : nil) || "none"

    if DEMO_TYPES.include?(type)
      "demos/#{type}"
    else
      Bridgetown.logger.warn "Demo",
        "tipo desconhecido #{type.inspect} em #{resource.relative_path}, usando 'none'"
      "demos/none"
    end
  end
end
