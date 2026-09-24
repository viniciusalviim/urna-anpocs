# Prepara o banco da rodada de teste (projeto Neon urna-teste). RODA UMA VEZ.
#
# - carimba o banco como 'teste' (só se ele não tiver carimbo);
# - cria as tabelas;
# - cadastra as duas chapas de exemplo;
# - deixa a urna FECHADA, em modo teste, com abstenção permitida;
# - carrega 60 participantes (logins rodada-01 a rodada-60);
# - gera os dois CSV de senhas.
#
# As senhas deste script vão para pessoas de verdade. Ele se recusa a rodar
# de novo num banco que já tem participantes: geraria senhas novas, e as já
# enviadas deixariam de valer. Se ele falhar no meio, apague e recrie o
# projeto no Neon, e rode de novo.
#
# Para rodar (na pasta do projeto):
#   Rscript rodada/01_preparar_banco_rodada.R

source("rodada/conectar_rodada.R")
source("R/credenciais.R")
source("dev/exemplos.R")

N <- 60
ARQUIVO_ATIVAS   <- "saida/RODADA_senhas_ATIVAS_enviar_aos_participantes.csv"
ARQUIVO_RESERVAS <- "saida/RODADA_senhas_RESERVAS_guardar_com_a_mesa.csv"

con <- conectar_rodada()

# 1. Carimbo: vazio ou 'teste'. Qualquer outro, para.
amb <- ambiente_do_banco(con)
if (!is.na(amb) && amb != "teste") {
  stop("PARADO. Este banco esta carimbado como '", amb, "'.\n",
       "Confira URNA_TESTE_PG_* no .Renviron. Nada foi feito.", call. = FALSE)
}

# 2. Já preparado? Para.
tem_tabelas <- !is.na(DBI::dbGetQuery(con,
  "select to_regclass('public.programas')::text as t")$t)
if (tem_tabelas) {
  n <- DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n
  if (n > 0) {
    stop("Este banco ja foi preparado: tem ", n, " participantes.\n",
         "Rodar de novo geraria senhas novas. Nada foi feito.", call. = FALSE)
  }
}

# 3. Consegue escrever os dois CSV? Confere ANTES de gerar senhas.
dir.create("saida", showWarnings = FALSE)
exigir_escrita(c(ARQUIVO_ATIVAS, ARQUIVO_RESERVAS))

# 4. Carimbo, tabelas, chapas e urna.
if (is.na(amb)) marcar_ambiente(con, "teste")
exigir_ambiente(con, "teste")

if (!tem_tabelas) executar_sql(con, "sql/001_schema.sql")

if (DBI::dbGetQuery(con, "select count(*)::int as n from chapas")$n == 0) {
  invisible(cadastrar_chapas_exemplo(con))
}

invisible(DBI::dbExecute(con,
  "insert into urna (id, estado, modo, permite_abstencao)
   values (1, 'fechada', 'teste', true)
   on conflict (id) do nothing"))

# 5. Participantes e senhas.
cat("Gerando", N * 3, "senhas e hashes. Leva alguns segundos...\n")
saida <- carregar_programas(con, programas_rodada(N))

s <- separar_senhas(saida)
write.csv(s$ativas,   ARQUIVO_ATIVAS,   row.names = FALSE, fileEncoding = "UTF-8")
write.csv(s$reservas, ARQUIVO_RESERVAS, row.names = FALSE, fileEncoding = "UTF-8")

cat("\nSenhas ATIVAS  (", nrow(s$ativas),   "): ", ARQUIVO_ATIVAS,   "\n", sep = "")
cat("Senhas RESERVA (", nrow(s$reservas), "): ", ARQUIVO_RESERVAS, "\n", sep = "")

# 6. Resumo.
cat("\nNo banco:\n")
print(DBI::dbGetQuery(con,
  "select (select valor from ambiente)                                  as carimbo,
          (select count(*)::int from programas)                         as participantes,
          (select count(*)::int from credenciais where ativa)           as ativas,
          (select count(*)::int from credenciais where not ativa)       as reservas,
          (select count(*)::int from chapas)                            as chapas"))
cat("\nUrna:\n")
imprimir_situacao(situacao_urna(con))

DBI::dbDisconnect(con)
cat("\nPronto. A urna esta FECHADA: abra com rodada/abrir_urna_rodada.R\n")
