require "test_helper"
require "rexml/document"

class FeedsTest < Minitest::Test
  include OutputHelpers

  POST = "2026/08/16/porting-dos-assembly-to-the-browser/".freeze

  def feed(path)
    REXML::Document.new(page_body(path))
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

    assert_equal ["Porting DOS assembly to the browser"],
      REXML::XPath.match(en, "//entry/title").map(&:text)
    assert_equal ["Portando assembly de DOS para o navegador"],
      REXML::XPath.match(pt, "//entry/title").map(&:text)
    assert_equal "pt", pt.root.attributes["xml:lang"]
  end

  def test_entries_link_absolutely_and_carry_the_full_post
    entry = REXML::XPath.first(feed("pt/feed.xml"), "//entry")

    assert_equal "https://viniciuscole.com/pt/#{POST}",
      REXML::XPath.first(entry, "link").attributes["href"]
    assert_includes REXML::XPath.first(entry, "content").text,
      "<p>Meu jogo da velha"
    assert_includes REXML::XPath.match(entry, "category").map { |c| c.attributes["label"] }, "Emulação"
  end

  def test_post_body_is_not_reindented_inside_the_feed
    content = REXML::XPath.first(feed("feed.xml"), "//entry/content").text
    assert_match(/^compiler that turns that into WebAssembly/, content)
  end

  def test_pages_advertise_the_feed_of_their_locale
    assert_includes page_body("index.html"),
      'type="application/atom+xml" title="Vinicius Cole (en)" href="https://viniciuscole.com/feed.xml"'
    assert_includes page_body("pt/index.html"),
      'href="https://viniciuscole.com/pt/feed.xml"'
    assert_includes page_body("pt/blog/index.html"), 'href="/pt/feed.xml" class="feed-link"'
  end
end
