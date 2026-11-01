require "erb"

class Builders::Feeds < SiteBuilder
  def self.path_for(locale, default_locale)
    "#{Builders::SiteHelpers.prefix_for(locale, default_locale)}feed.xml"
  end

  def build
    hook :site, :post_write do |site|
      site.config.available_locales.each { |locale| write_feed(site, locale.to_s) }
    end

    helper :feed_url do |locale|
      "/#{Builders::Feeds.path_for(locale, site.config.default_locale)}"
    end
  end

  private

  def write_feed(site, locale)
    posts = site.collections.posts.resources
      .select { |post| post.data.locale.to_s == locale }
      .sort_by(&:date).reverse
    return if posts.empty?

    path = self.class.path_for(locale, site.config.default_locale)
    destination = File.join(site.config.destination, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, atom(site, locale, path, posts))
  end

  def atom(site, locale, path, posts)
    base = site.config.url.to_s.chomp("/")
    prefix = Builders::SiteHelpers.prefix_for(locale, site.config.default_locale)
    feed_url = "#{base}/#{path}"
    title = I18n.t("site.title", locale: locale)

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom" xml:lang="#{locale}" xml:base="#{base}/">
        <title>#{h title}</title>
        <subtitle>#{h I18n.t("blog.intro", locale: locale)}</subtitle>
        <link href="#{feed_url}" rel="self" type="application/atom+xml"/>
        <link href="#{base}/#{prefix}blog/" rel="alternate" type="text/html"/>
        <id>#{feed_url}</id>
        <updated>#{timestamp posts.first.date}</updated>
        <author><name>#{h title}</name></author>
      #{posts.map { |post| entry(post, locale) }.join}</feed>
    XML
  end

  def entry(post, locale)
    url = post.absolute_url
    categories = Builders::TagPages.tags_of(post).map do |tag|
      %(<category term="#{h tag}" label="#{h Builders::TagPages.label_for(tag, locale)}"/>)
    end

    lines = [
      "<title>#{h post.data.title}</title>",
      %(<link href="#{url}" rel="alternate" type="text/html"/>),
      "<id>#{url}</id>",
      "<published>#{timestamp post.date}</published>",
      "<updated>#{timestamp(post.data.updated || post.date)}</updated>",
      *categories,
      %(<content type="html">#{h post.content}</content>),
    ]

    "  <entry>\n#{lines.map { |line| "    #{line}\n" }.join}  </entry>\n"
  end

  def timestamp(time)
    time.to_time.utc.iso8601
  end

  def h(text)
    ERB::Util.html_escape(text.to_s)
  end
end
