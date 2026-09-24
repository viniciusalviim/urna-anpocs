# Conexão dos scripts da rodada de teste.
#
# Sempre com as variáveis URNA_TESTE_PG_* do .Renviron, nunca com URNA_PG_*
# (que apontam para o dev). Sem elas, o script para.

source("R/db.R")
source("R/voto.R")
source("R/urna.R")

conectar_rodada <- function() {
  con <- conectar("URNA_TESTE_PG")
  cat("Banco:", Sys.getenv("URNA_TESTE_PG_HOST"), "/",
      Sys.getenv("URNA_TESTE_PG_DB"), "\n\n")
  con
}
