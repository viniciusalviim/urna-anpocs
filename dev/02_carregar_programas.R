# Carrega 119 programas SINTETICOS no banco de desenvolvimento e gera o CSV
# com as senhas, exatamente como vai acontecer com a lista real depois de
# 28/09 — so que com dados falsos.
#
# ATENCAO: apaga tudo o que estiver no banco de dev antes de carregar.

source("R/db.R")
source("R/voto.R")
source("R/credenciais.R")
source("dev/ferramentas_dev.R")

N <- 119

con <- conectar()
exigir_banco_dev(con)
zerar_banco_dev(con, "sql/001_schema.sql")

cat("Gerando", N * 3, "senhas e hashes. Leva alguns segundos...\n")
t0 <- Sys.time()
saida <- carregar_programas(con, programas_sinteticos(N))
cat("Pronto em", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "segundos.\n\n")

dir.create("saida", showWarnings = FALSE)
arquivo <- "saida/credenciais_DEV_sinteticas.csv"
write.csv(saida, arquivo, row.names = FALSE, fileEncoding = "UTF-8")
cat("Senhas gravadas em:", arquivo, "\n\n")

cat("Primeiras linhas do CSV:\n")
print(head(saida, 6))

cat("\nNo banco:\n")
print(DBI::dbGetQuery(con,
  "select (select count(*)::int from programas)   as programas,
          (select count(*)::int from credenciais) as credenciais"))

DBI::dbDisconnect(con)
