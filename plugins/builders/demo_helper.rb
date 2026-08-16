class Builders::DemoHelper < SiteBuilder
  # Tipos de demo suportados. Acrescentar um tipo aqui e criar o partial
  # correspondente em src/_partials/demos/_<tipo>.erb e tudo que e preciso
  # para um projeto novo embutir uma demo.
  DEMO_TYPES = %w[none jsdos].freeze

  def build
    helper :demo_partial_for do |resource|
      type = resource.data.dig(:demo, :type) || "none"

      if DEMO_TYPES.include?(type)
        "demos/#{type}"
      else
        Bridgetown.logger.warn "Demo",
          "tipo desconhecido #{type.inspect} em #{resource.relative_path}, usando 'none'"
        "demos/none"
      end
    end
  end
end
