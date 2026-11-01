require "test_helper"
require "rexml/document"

class FeedsTest < Minitest::Test
  include OutputHelpers

  POST = "2026/08/16/porting-dos-assembly-to-the-browser/".freeze

  def feed(path)
    REXML::Document.new(page_body(path))
  end

  def entry_for(path, url)
    REXML::XPath.match(feed(path), "//entry").find { |entry| REXML::XPath.first(entry, "id").text == url } ||
      flunk("#{path} nao tem entrada para #{url}")
  end

  def test_each_locale_has_a_well_formed_atom_feed
    %w[feed.xml pt/feed.xml].each do |path|
      root = feed(path).root
      assert_equal "feed", root.name
      assert_equal "http://www.w3.org/2005/Atom", root.namespace
    end
  end

  def test_feeds_only_carry_posts_in_their_own_locale
    en = feed("feed.xml")
    pt = feed("pt/feed.xml")

    en_titles = REXML::XPath.match(en, "//entry/title").map(&:text)
    pt_titles = REXML::XPath.match(pt, "//entry/title").map(&:text)

    assert_includes en_titles, "Porting DOS assembly to the browser"
    refute_includes en_titles, "Portando assembly de DOS para o navegador"
    assert_includes pt_titles, "Portando assembly de DOS para o navegador"
    refute_includes pt_titles, "Porting DOS assembly to the browser"
    assert_equal en_titles.size, pt_titles.size
    assert_equal "pt", pt.root.attributes["xml:lang"]
  end

  def test_entries_link_absolutely_and_carry_the_full_post
    entry = entry_for("pt/feed.xml", "https://viniciuscole.com/pt/#{POST}")

    assert_equal "https://viniciuscole.com/pt/#{POST}",
      REXML::XPath.first(entry, "link").attributes["href"]
    assert_includes REXML::XPath.first(entry, "content").text,
      "<p>Meu jogo da velha"
    assert_includes REXML::XPath.match(entry, "category").map { |c| c.attributes["label"] }, "Emulação"
  end

  def test_post_body_is_not_reindented_inside_the_feed
    entry = entry_for("feed.xml", "https://viniciuscole.com/#{POST}")
    content = REXML::XPath.first(entry, "content").text
    assert_match(/^compiler that turns that into WebAssembly/, content)
  end

  def test_newest_post_comes_first
    dates = REXML::XPath.match(feed("feed.xml"), "//entry/published").map(&:text)
    assert_equal dates.sort.reverse, dates
  end

  def test_pages_advertise_the_feed_of_their_locale
    assert_includes page_body("index.html"),
      'type="application/atom+xml" title="Vinicius Cole (en)" href="https://viniciuscole.com/feed.xml"'
    assert_includes page_body("pt/index.html"),
      'href="https://viniciuscole.com/pt/feed.xml"'
    assert_includes page_body("pt/blog/index.html"), 'href="/pt/feed.xml" class="feed-link"'
  end
end
