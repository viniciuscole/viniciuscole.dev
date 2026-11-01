require "test_helper"
require "rexml/document"

class SitemapTest < Minitest::Test
  include OutputHelpers

  def sitemap
    @sitemap ||= REXML::Document.new(page_body("sitemap.xml"))
  end

  def locs
    REXML::XPath.match(sitemap, "//url/loc").map(&:text)
  end

  def test_every_indexable_html_page_is_listed
    expected = html_pages
      .reject { |path| File.read(path).include?('name="robots" content="noindex"') }
      .map { |path| "https://viniciuscole.com/" + Pathname(path).relative_path_from(OUTPUT).to_s.delete_suffix("index.html") }

    assert_equal expected.sort, locs.sort
  end

  def test_error_pages_stay_out
    refute(locs.any? { |loc| loc.match?(/404|500/) })
  end

  def test_translated_pages_list_both_locales_in_order
    url = REXML::XPath.match(sitemap, "//url").find do |node|
      REXML::XPath.first(node, "loc").text == "https://viniciuscole.com/pt/projects/car-routes/"
    end
    alternates = REXML::XPath.match(url, "xhtml:link").map { |l| [l.attributes["hreflang"], l.attributes["href"]] }

    assert_equal [
      ["en", "https://viniciuscole.com/projects/car-routes/"],
      ["pt", "https://viniciuscole.com/pt/projects/car-routes/"],
    ], alternates
  end

  def test_robots_points_at_the_sitemap
    assert_includes page_body("robots.txt"), "Sitemap: https://viniciuscole.com/sitemap.xml"
  end
end
