// Agrupados por largura aproximada numa fonte proporcional. O glifo sai da
// mesma classe da letra que substitui para a linha nao mudar de tamanho —
// um "i" virando "W" empurra a quebra de linha e tudo abaixo pula.
const CLASSES = [
  "0123456789",
  "ijlt", "fr", "abcdeghknopqsuvxyz", "mw",
  "IJ", "ABCDEFGHKLNOPQRSTUVXYZ", "MW",
]
const PADRAO_MAIUSCULA = "ABCDEFGHKLNOPQRSTUVXYZ"
const PADRAO_MINUSCULA = "abcdeghknopqsuvxyz"

// Fracao da duracao em que cada letra fica embaralhada, e chance por quadro
// de o glifo trocar. Juntos e o "peso" do efeito: janela curta e troca rara
// dao uma faixa estreita de letras se mexendo devagar.
const INICIO_MAXIMO = 0.55
const RUIDO_INICIO = 0.2
const JANELA_MINIMA = 0.12
const RUIDO_JANELA = 0.13
const REROLAGEM = 0.35

function alfabeto(letra) {
  const classe = CLASSES.find((c) => c.includes(letra))
  if (classe) return classe
  if (letra.toLowerCase() === letra.toUpperCase()) return PADRAO_MINUSCULA
  return letra === letra.toUpperCase() ? PADRAO_MAIUSCULA : PADRAO_MINUSCULA
}

// Morfa `de` em `para` letra a letra: cada posicao mostra a letra antiga,
// depois glifos por uma janela curta, depois a letra nova. As janelas
// avancam da esquerda para a direita com ruido.
export function criarEmbaralhador(de, para, { aleatorio = Math.random } = {}) {
  const antigas = [...de]
  const novas = [...para]
  const total = Math.max(antigas.length, novas.length)
  const ultimo = Math.max(1, total - 1)
  const janelas = Array.from({ length: total }, (_, i) => {
    const inicio = (i / ultimo) * INICIO_MAXIMO + aleatorio() * RUIDO_INICIO
    return [inicio, inicio + JANELA_MINIMA + aleatorio() * RUIDO_JANELA]
  })
  const glifos = new Array(total).fill(null)

  return (progresso) => {
    let saida = ""
    for (let i = 0; i < total; i++) {
      const nova = novas[i] ?? ""
      const [inicio, fim] = janelas[i]
      if (progresso >= 1 || progresso >= fim) {
        saida += nova
      } else if (progresso < inicio) {
        saida += antigas[i] ?? ""
      } else if (nova === "" || /\s/.test(nova)) {
        saida += nova
      } else {
        if (glifos[i] === null || aleatorio() < REROLAGEM) {
          const letras = alfabeto(nova)
          glifos[i] = letras[Math.floor(aleatorio() * letras.length)]
        }
        saida += glifos[i]
      }
    }
    return saida
  }
}
