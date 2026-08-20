require "test_helper"
require "zip"

class GameBundleTest < Minitest::Test
  include OutputHelpers

  BUNDLE = "demos/tic-tac-toe/vca.jsdos".freeze

  # O tamanho exato e a trava de reprodutibilidade desta receita. O toolchain
  # nao e fixado por versao — nem o Open Watcom, nem o clone do assembly — entao
  # e este numero que denuncia qualquer deriva.
  #
  # Se voce mudou o assembly de proposito, atualize a constante junto: essa
  # atualizacao consciente e o ponto do teste, nao um obstaculo.
  TAMANHO_ESPERADO = 3_244

  def test_bundle_is_versioned_in_the_repository
    assert ROOT.join("src", BUNDLE).file?,
      "faltou src/#{BUNDLE} — rode `rake game:build`"
  end

  def test_bundle_is_published
    assert output(BUNDLE).file?, "o bundle nao chegou em output/"
  end

  def test_bundle_carries_the_executable_and_the_dosbox_config
    nomes = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.map(&:name) }

    assert_includes nomes, "VCA.EXE"
    assert_includes nomes, ".jsdos/dosbox.conf"
  end

  def test_the_packaged_executable_is_a_real_dos_binary
    conteudo = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.read("VCA.EXE") }

    assert_equal "MZ", conteudo[0, 2],
      "VCA.EXE nao comeca com a assinatura MZ de executavel DOS"
    assert_equal TAMANHO_ESPERADO, conteudo.bytesize,
      "VCA.EXE tem #{conteudo.bytesize} bytes, esperava #{TAMANHO_ESPERADO}. " \
      "Ou o toolchain mudou, ou o assembly mudou — investigue antes de ajustar o numero."
  end

  def test_the_dosbox_config_runs_the_game_on_startup
    conf = Zip::File.open(ROOT.join("src", BUNDLE)) { |zip| zip.read(".jsdos/dosbox.conf") }

    assert_includes conf, "[autoexec]"
    assert_includes conf, "VCA.EXE"
    assert_includes conf, "machine=vgaonly"
  end
end
