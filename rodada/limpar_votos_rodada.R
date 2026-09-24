# Limpa os votos da rodada de teste, para uma nova sessão.
#
# Apaga votos, votantes e log, e volta a urna para FECHADA. As credenciais
# ficam: as mesmas senhas valem na sessão seguinte.
#
# Antes de apagar, grava em saida/ três CSV com a data no nome:
#   RODADA_arquivo_<data>_log.csv, _votantes.csv e _votos.csv
#
# Só roda com a urna encerrada (ou nunca aberta) e num banco carimbado
# 'teste'. Nunca em produção.
#
# Para rodar:
#   1. escreva a confirmação abaixo, exatamente como indicado;
#   2. Rscript rodada/limpar_votos_rodada.R
#   3. volte a confirmação para "" depois.

CONFIRMACAO <- ""     # escreva: APAGAR VOTOS DA RODADA

source("rodada/conectar_rodada.R")
source("dev/ferramentas_dev.R")

if (!identical(CONFIRMACAO, "APAGAR VOTOS DA RODADA")) {
  stop("Confirmacao ausente. Abra rodada/limpar_votos_rodada.R e escreva\n",
       "  CONFIRMACAO <- \"APAGAR VOTOS DA RODADA\"\n",
       "Nada foi apagado.", call. = FALSE)
}

con <- conectar_rodada()
exigir_ambiente(con, "teste")

cat("Antes:\n")
imprimir_situacao(situacao_urna(con))

r <- limpar_votos(con, pasta = "saida")

cat("\nArquivado antes de apagar:\n")
cat(paste0("  ", r$arquivos, collapse = "\n"), "\n")
cat("  (", r$votantes, " votantes, ", r$votos, " votos, ", r$log,
    " linhas de log)\n\n", sep = "")

cat("Agora:\n")
imprimir_situacao(situacao_urna(con))
DBI::dbDisconnect(con)

cat("\nPronto. Volte CONFIRMACAO para \"\" neste arquivo.\n",
    "Para a proxima sessao: rodada/abrir_urna_rodada.R\n", sep = "")
