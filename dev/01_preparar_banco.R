# Prepara o banco de DESENVOLVIMENTO vazio: carimba 'dev' e cria as tabelas.
# Rode uma vez por banco. O carimbo fica gravado dentro do banco e nao pode
# ser trocado rodando este script de novo.
#
# Os bancos do sistema de teste e do sistema final NAO sao preparados por
# este script, e sim por preparar/preparar_banco.R (que carimba, cria as
# tabelas e carrega a lista oficial).

AMBIENTE <- "dev"

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
