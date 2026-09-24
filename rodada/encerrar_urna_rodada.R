# Encerra a urna da rodada de teste (aberta -> encerrada).
# Espera terminar qualquer voto que esteja sendo gravado.
#
#   Rscript rodada/encerrar_urna_rodada.R

source("rodada/conectar_rodada.R")

con <- conectar_rodada()
exigir_ambiente(con, "teste")

cat("Antes:\n")
imprimir_situacao(situacao_urna(con))

r <- encerrar_urna(con)
if (isTRUE(r$ok)) {
  cat("\n>>> URNA ENCERRADA <<<\n")
  if (!isTRUE(r$integridade$ok)) {
    cat("\n!!! INCIDENTE: votantes (", r$integridade$votantes, ") e votos (",
        r$integridade$votos, ") nao batem. Nao limpe este banco: guarde-o como esta.\n",
        sep = "")
  }
  cat("\n")
} else {
  cat("\n>>> NAO ENCERROU:", explicar_motivo_urna(r$motivo), "\n\n")
}

cat("Agora:\n")
imprimir_situacao(situacao_urna(con))
DBI::dbDisconnect(con)
