# Mostra a situação da urna da rodada de teste. Não muda nada.
#
#   Rscript rodada/situacao_urna_rodada.R

source("rodada/conectar_rodada.R")

con <- conectar_rodada()
exigir_ambiente(con, "teste")
imprimir_situacao(situacao_urna(con))
DBI::dbDisconnect(con)
