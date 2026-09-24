# Abre a urna da rodada de teste (fechada -> aberta).
#
#   Rscript rodada/abrir_urna_rodada.R

source("rodada/conectar_rodada.R")

con <- conectar_rodada()
exigir_ambiente(con, "teste")

cat("Antes:\n")
imprimir_situacao(situacao_urna(con))

r <- abrir_urna(con)
if (isTRUE(r$ok)) {
  cat("\n>>> URNA ABERTA <<<\n\n")
} else {
  cat("\n>>> NAO ABRIU:", explicar_motivo_urna(r$motivo), "\n")
  if (identical(r$motivo, "ja_encerrada")) {
    cat("    Para uma nova sessao: rode rodada/limpar_votos_rodada.R e abra de novo.\n")
  }
  cat("\n")
}

cat("Agora:\n")
imprimir_situacao(situacao_urna(con))
DBI::dbDisconnect(con)
