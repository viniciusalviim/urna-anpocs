# Prepara um banco vazio: carimba o ambiente e cria as tabelas.
# Rode uma vez por banco.
#
# ATENCAO: a linha abaixo e a unica coisa que voce muda ao preparar o banco
# da eleicao. O carimbo fica gravado dentro do banco e nao pode ser trocado
# rodando este script de novo.

AMBIENTE <- "dev"        # "dev" ou "producao"
                         # (o banco da rodada, 'teste', e preparado por
                         #  rodada/01_preparar_banco_rodada.R, nao por este)

source("R/db.R")

con <- conectar()

cat("Banco:", Sys.getenv("URNA_PG_HOST"), "/", Sys.getenv("URNA_PG_DB"), "\n")
cat("Carimbando como:", AMBIENTE, "\n\n")

marcar_ambiente(con, AMBIENTE)
cat("Carimbo gravado no banco:", ambiente_do_banco(con), "\n")

executar_sql(con, "sql/001_schema.sql")
cat("\nTabelas criadas:\n")
print(DBI::dbListTables(con))

DBI::dbDisconnect(con)
