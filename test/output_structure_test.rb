require "test_helper"

class OutputStructureTest < Minitest::Test
  include OutputHelpers

  def test_home_is_generated
    assert_page "index.html"
  end
end
