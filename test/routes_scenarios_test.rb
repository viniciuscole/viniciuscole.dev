require "test_helper"
require "json"

class RoutesScenariosTest < Minitest::Test
  include OutputHelpers

  def cenarios
    JSON.parse(output("demos/car-routes/cenarios.json").read)
  end

  def test_the_scenarios_are_published
    assert output("demos/car-routes/cenarios.json").file?
  end

  def test_the_four_scenarios_exist
    assert_equal %w[dijkstra engarrafamento tarde-demais via-libera], cenarios.keys.sort
  end

  def test_every_scenario_is_coherent
    cenarios.each do |id, c|
      ids = c["nos"].map { |n| n["id"] }
      assert_equal (1..ids.length).to_a, ids.sort, "#{id}: ids devem ser 1..N"
      c["nos"].each do |n|
        assert (0.0..1.0).cover?(n["x"]) && (0.0..1.0).cover?(n["y"]), "#{id}: no #{n['id']} fora de [0,1]"
      end
      c["arestas"].each do |a|
        assert ids.include?(a["de"]) && ids.include?(a["para"]), "#{id}: aresta #{a['de']}->#{a['para']} com no inexistente"
        assert_operator a["m"], :>, 0
      end
      refute_equal c["origem"], c["destino"], "#{id}: origem igual ao destino"
      assert_operator c["kmh"], :>, 0
      chaves = c["arestas"].map { |a| [a["de"], a["para"]] }
      c["atualizacoes"].each do |u|
        assert chaves.include?([u["de"], u["para"]]), "#{id}: atualizacao em via inexistente #{u['de']}->#{u['para']}"
        assert_operator u["kmh"], :>, 0
      end
      assert_equal c["atualizacoes"], c["atualizacoes"].sort_by { |u| u["t"] }, "#{id}: atualizacoes fora de ordem"
    end
  end

  def test_every_player_in_the_page_references_a_scenario
    %w[projects/car-routes/index.html pt/projects/car-routes/index.html].each do |pagina|
      usados = page_body(pagina).scan(/data-rotas="([^"]+)"/).flatten.uniq
      refute_empty usados
      (usados - cenarios.keys).each { |id| flunk "#{pagina} usa o cenario #{id}, que nao existe" }
    end
  end
end
