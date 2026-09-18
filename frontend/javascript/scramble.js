export const GLIFOS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789<>/[]{}#%&*+=?@"

const PESO_POSICAO = 0.6

// Cada letra ganha um limiar de progresso: a posicao no texto pesa 60% e um
// sorteio 40%, entao a resolucao varre da esquerda para a direita com ruido,
// em vez de um cursor rigido.
export function criarEmbaralhador(texto, { direcao = "entrada", aleatorio = Math.random } = {}) {
  const letras = [...texto]
  const ultimo = Math.max(1, letras.length - 1)
  const limiares = letras.map((_, i) => (i / ultimo) * PESO_POSICAO + aleatorio() * (1 - PESO_POSICAO))
  const glifo = () => GLIFOS[Math.floor(aleatorio() * GLIFOS.length)]

  return (progresso) => {
    let saida = ""
    for (let i = 0; i < letras.length; i++) {
      const letra = letras[i]
      if (/\s/.test(letra)) {
        saida += letra
        continue
      }
      const passou = progresso >= 1 || progresso > limiares[i]
      const mostraFinal = direcao === "entrada" ? passou : !passou
      saida += mostraFinal ? letra : glifo()
    }
    return saida
  }
}
