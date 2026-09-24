# Carrega 119 programas SINTETICOS no banco de desenvolvimento e gera os dois
# CSV de senhas, exatamente como vai acontecer com a lista real depois de
# 28/09 — so que com dados falsos:
# - ATIVAS: uma por programa, a que a secretaria envia aos coordenadores;
# - RESERVAS: as outras duas de cada programa, guardadas com a mesa.
#
# ATENCAO: apaga tudo o que estiver no banco de dev antes de carregar.

source("R/db.R")
source("R/voto.R")
source("R/credenciais.R")
source("dev/ferramentas_dev.R")

N <- 119
ARQUIVO_ATIVAS   <- "saida/DEV_senhas_ATIVAS_enviar_aos_coordenadores.csv"
ARQUIVO_RESERVAS <- "saida/DEV_senhas_RESERVAS_guardar_com_a_mesa.csv"

# Confere ANTES de gerar que da para escrever os dois CSV (ver exigir_escrita).
dir.create("saida", showWarnings = FALSE)
exigir_escrita(c(ARQUIVO_ATIVAS, ARQUIVO_RESERVAS))

con <- conectar()
exigir_banco_dev(con)
zerar_banco_dev(con, "sql/001_schema.sql")

cat("Gerando", N * 3, "senhas e hashes. Leva alguns segundos...\n")
t0 <- Sys.time()
saida <- carregar_programas(con, programas_sinteticos(N))
cat("Pronto em", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "segundos.\n\n")

s <- separar_senhas(saida)
write.csv(s$ativas,   ARQUIVO_ATIVAS,   row.names = FALSE, fileEncoding = "UTF-8")
write.csv(s$reservas, ARQUIVO_RESERVAS, row.names = FALSE, fileEncoding = "UTF-8")
cat("Senhas ativas  (", nrow(s$ativas),   ") gravadas em: ", ARQUIVO_ATIVAS,   "\n", sep = "")
cat("Senhas reserva (", nrow(s$reservas), ") gravadas em: ", ARQUIVO_RESERVAS, "\n\n", sep = "")

cat("Primeiras linhas das ativas:\n")
print(head(s$ativas, 3))

cat("\nNo banco:\n")
print(DBI::dbGetQuery(con,
  "select (select count(*)::int from programas)   as programas,
          (select count(*)::int from credenciais) as credenciais"))

DBI::dbDisconnect(con)
