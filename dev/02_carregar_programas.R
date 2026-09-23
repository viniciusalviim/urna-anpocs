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
ARQUIVO_SAIDA <- "saida/credenciais_DEV_sinteticas.csv"

# Confere ANTES de gerar que da para escrever o CSV.
# Se o arquivo estiver aberto no Excel, a escrita falharia DEPOIS da carga,
# e as senhas ficariam so no banco, em forma de hash, perdidas para sempre.
dir.create("saida", showWarnings = FALSE)
pode_escrever <- tryCatch({
  f <- file(ARQUIVO_SAIDA, "a"); close(f); TRUE
}, error = function(e) FALSE, warning = function(e) FALSE)

if (!pode_escrever) {
  stop("Nao consigo escrever em ", ARQUIVO_SAIDA,
       ".\nO arquivo esta aberto em outro programa (Excel?). ",
       "Feche e rode de novo.\nNada foi gerado.", call. = FALSE)
}

con <- conectar()
exigir_banco_dev(con)
zerar_banco_dev(con, "sql/001_schema.sql")

cat("Gerando", N * 3, "senhas e hashes. Leva alguns segundos...\n")
t0 <- Sys.time()
saida <- carregar_programas(con, programas_sinteticos(N))
cat("Pronto em", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "segundos.\n\n")

write.csv(saida, ARQUIVO_SAIDA, row.names = FALSE, fileEncoding = "UTF-8")
cat("Senhas gravadas em:", ARQUIVO_SAIDA, "\n\n")

cat("Primeiras linhas do CSV:\n")
print(head(saida, 6))

cat("\nNo banco:\n")
print(DBI::dbGetQuery(con,
  "select (select count(*)::int from programas)   as programas,
          (select count(*)::int from credenciais) as credenciais"))

DBI::dbDisconnect(con)
