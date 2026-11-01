require "erb"

class Builders::Sitemap < SiteBuilder
  def build
    hook :site, :post_write do |site|
      File.write(File.join(site.config.destination, "sitemap.xml"), sitemap(site))
    end
  end

  private

  def sitemap(site)
    base = site.config.url.to_s.chomp("/")
    pages = indexable(site).sort_by { |page| path_of(page) }
    locales = site.config.available_locales.map(&:to_s)

    urls = pages.map do |page|
      variants = page.all_locales.sort_by { |variant| locales.index(variant.data.locale.to_s) || locales.size }
      alternates = variants.map do |variant|
        %(    <xhtml:link rel="alternate" hreflang="#{variant.data.locale}" href="#{base}#{path_of(variant)}"/>\n)
      end
      alternates = [] if alternates.size < 2

      "  <url>\n    <loc>#{ERB::Util.html_escape(base + path_of(page))}</loc>\n#{alternates.join}  </url>\n"
    end

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      #{urls.join}</urlset>
    XML
  end

  def indexable(site)
    resources = site.resources.select { |resource| resource.output_ext == ".html" }
    generated = site.generated_pages.select(&:html?)

    (resources + generated).reject do |page|
      page.data.noindex || page.data.sitemap == false
    end
  end

  def path_of(page)
    page.respond_to?(:relative_url) ? page.relative_url : page.url
  end
end
