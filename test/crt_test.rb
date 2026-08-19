require "test_helper"

class CrtTest < Minitest::Test
  include OutputHelpers

  def css
    ROOT.join("frontend/styles/crt.css").read
  end

  def test_the_crt_stylesheet_exists
    assert ROOT.join("frontend/styles/crt.css").file?
  end

  def test_every_class_the_demo_emits_has_styling
    %w[.demo-jsdos .demo-frame .demo-start .demo-weight .demo-screen
       .demo-error .demo-instructions .demo-license
       .demo-keypad .keypad-grid .keypad-marks .keypad-actions].each do |classe|
      assert_includes css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end

  def test_it_reuses_the_palette_instead_of_inventing_colours
    assert_includes css, "var(--vga-", "o CRT deveria usar os tokens VGA existentes"
  end

  def test_animation_respects_reduced_motion
    assert_includes css, "prefers-reduced-motion",
      "o tratamento CRT precisa desligar animacao para quem pede menos movimento"
  end

  def test_the_stylesheet_is_imported
    assert_includes ROOT.join("frontend/styles/index.css").read, "crt.css"
  end
end
