# Dados de exemplo dos testes automáticos. Nada aqui é real.
# (A chapa de exemplo do dev e do sistema de teste está em preparar/chapas.R.)

# Os 60 participantes da rodada de teste antiga: logins rodada-01 a rodada-60.
# Usado pelos testes da limpeza de votos entre sessões.
programas_rodada <- function(n = 60) {
  i <- seq_len(n)
  data.frame(
    id           = sprintf("rod%02d", i),
    nome_oficial = sprintf("Participante da rodada %02d", i),
    tipo         = "ppg",
    login        = sprintf("rodada-%02d", i),
    stringsAsFactors = FALSE
  )
}
