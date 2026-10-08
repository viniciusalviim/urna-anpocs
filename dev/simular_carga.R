# Simulação de muitos votos ao mesmo tempo, no banco de DEV.
#
# Recria o banco de dev com 119 programas sintéticos (PINs só na memória,
# nunca em arquivo), abre a urna e manda N_PROCESSOS processos entrarem e
# votarem ao mesmo tempo. DUPLICADOS programas recebem uma segunda tentativa
# de voto, de outro processo, quase no mesmo instante: o banco tem de recusar.
#
# No fim, confere: um voto por programa, votantes = votos, nenhum voto duplo,
# e mostra quanto tempo cada entrada e cada voto levaram.
#
# APAGA o banco de dev. Depois, rode dev/03_preparar_urna_dev.R.
#
#   Rscript dev/simular_carga.R

N_PROCESSOS <- 20
N_PROGRAMAS <- 119
DUPLICADOS  <- 20

source("R/db.R")
source("R/voto.R")
source("R/credenciais.R")
source("R/login.R")
source("dev/ferramentas_dev.R")
source("dev/carga.R")
source("preparar/chapas.R")

con <- conectar()
exigir_banco_dev(con)
zerar_banco_dev(con, "sql/001_schema.sql")

cat("Carregando", N_PROGRAMAS, "programas sinteticos (PINs so na memoria)...\n")
saida <- carregar_programas(con, programas_sinteticos(N_PROGRAMAS))
cadastrar_chapa(con, CHAPA_TESTE)
invisible(DBI::dbExecute(con,
  "insert into urna (id, estado, modo, permite_abstencao, aberta_em)
   values (1, 'aberta', 'teste', true, now())"))
ativas <- separar_senhas(saida)$ativas
rm(saida)

cat("Largada:", N_PROCESSOS, "processos,", N_PROGRAMAS, "votos e", DUPLICADOS,
    "tentativas de voto duplo, todos ao mesmo tempo...\n\n")
t0 <- Sys.time()
r <- votar_em_paralelo(ativas, n_processos = N_PROCESSOS, duplicados = DUPLICADOS,
                       raiz = ".", espera = 5)
duracao <- as.numeric(difftime(Sys.time(), t0, units = "secs")) - 5

i <- conferir_integridade(con)
aceitos <- tapply(r$ok, r$login, sum)
recusas <- table(r$motivo[!r$ok])

q <- function(x) sprintf("mediana %.2f s | 95%% abaixo de %.2f s | maximo %.2f s",
                         stats::median(x), stats::quantile(x, 0.95), max(x))
cat("Tentativas:          ", nrow(r), "\n")
cat("Votos aceitos:       ", sum(r$ok), "\n")
cat("Recusas:             ", if (length(recusas)) paste(names(recusas), recusas, sep = " = ", collapse = "; ") else "nenhuma", "\n")
cat("Votantes / votos:    ", i$votantes, "/", i$votos,
    if (isTRUE(i$ok)) "(integridade ok)" else "(INCIDENTE: nao batem)", "\n")
cat("Programas com 1 voto:", sum(aceitos == 1), "de", N_PROGRAMAS, "\n")
cat("Tempo da entrada:    ", q(r$seg_login), "\n")
cat("Tempo do voto:       ", q(r$seg_voto), "\n")
cat(sprintf("Duracao total:        %.1f s para %d tentativas\n\n", duracao, nrow(r)))

ok <- isTRUE(i$ok) && i$votantes == N_PROGRAMAS && all(aceitos == 1) &&
  all(r$motivo[!r$ok] %in% c("ja_votou", "login:ja_votou"))
cat(if (ok) ">>> APROVADO: um voto por programa, nenhum voto duplo, integridade ok.\n"
    else ">>> REPROVADO: veja os numeros acima.\n")

DBI::dbDisconnect(con)
cat("\nO banco de dev foi apagado e recarregado. Rode dev/03_preparar_urna_dev.R.\n")
