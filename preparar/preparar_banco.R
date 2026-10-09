# Prepara o banco do sistema de TESTE ou do sistema FINAL com a lista oficial.
# O mesmo script serve aos dois: só muda AMBIENTE, logo abaixo.
#
#   teste    -> lê URNA_TESTE_PG_* do .Renviron; carimbo 'teste'; urna em
#               modo teste; arquivos TESTE_PINS_...
#   producao -> lê URNA_PROD_PG_*; carimbo 'producao'; urna em modo oficial;
#               arquivos PRODUCAO_PINS_...
#   Nos dois: a chapa oficial (preparar/chapas.R).
#
# O que ele faz, num banco recém-criado no Neon:
#   1. lê e limpa a lista oficial (e para se ela tiver algo inesperado);
#   2. confere o carimbo do banco (vazio ou do mesmo ambiente);
#   3. se recusa a rodar num banco que já tem programas;
#   4. confere que consegue escrever os quatro CSV ANTES de gerar os PINs;
#   5. carimba, cria as tabelas, cadastra a chapa única e deixa a urna FECHADA;
#   6. carrega os programas da lista e as 10 credenciais avulsas
#      (credencial-01 a credencial-10), com 3 PINs cada (1 ativo, 2 reservas);
#   7. grava em saida/: PINs da lista (ativos, para a secretaria; reservas,
#      para a mesa) e PINs das avulsas (ativos e reservas, para a mesa).
#
# Os PINs vão para pessoas de verdade: quem roda é o responsável, no
# computador dele. Na pasta do projeto:
#   Rscript preparar/preparar_banco.R

AMBIENTE      <- "teste"     # "teste" ou "producao"
ARQUIVO_LISTA <- "saida/Lista_Assembleia_Final.xlsx"

stopifnot(AMBIENTE %in% c("teste", "producao"))

source("R/db.R")
source("R/voto.R")
source("R/credenciais.R")
source("R/urna.R")
source("preparar/chapas.R")
source("preparar/preparacao.R")

# 1. A lista, antes de encostar no banco.
lista <- ler_lista_oficial(ARQUIVO_LISTA)
cat("Lista oficial:", nrow(lista), "programas,",
    sum(lista$tipo == "centro"), "deles centros.\n")

avulsas  <- credenciais_avulsas(10)
cat("Credenciais avulsas:", nrow(avulsas), "(", avulsas$login[1], "a",
    avulsas$login[nrow(avulsas)], ")\n")

chapa    <- chapa_do_ambiente(AMBIENTE)
arquivos <- arquivos_de_pins(AMBIENTE, "saida")
prefixo  <- prefixo_do_ambiente(AMBIENTE)

con <- conectar(prefixo)
cat("Ambiente:", AMBIENTE, "\n")
cat("Banco:   ", Sys.getenv(paste0(prefixo, "_HOST")), "/",
    Sys.getenv(paste0(prefixo, "_DB")), "\n\n")

cat("Preparando o banco (se ele estiver vazio, gera", 3 * (nrow(lista) + nrow(avulsas)),
    "PINs e hashes; leva alguns segundos)...\n")
r <- tryCatch(preparar_banco(con, AMBIENTE, lista, chapa, arquivos, avulsas = avulsas),
              error = function(e) { DBI::dbDisconnect(con); stop(e) })

cat("\nPINs ATIVOS  (", r$ativas,   "): ", r$arquivos[["ativas"]],   "  <- secretaria\n", sep = "")
cat("PINs RESERVA (", r$reservas, "): ", r$arquivos[["reservas"]], "  <- mesa\n", sep = "")
cat("AVULSAS      (", r$avulsas,  "): ", r$arquivos[["avulsas_ativas"]], "  <- mesa\n", sep = "")
cat("              e reservas delas: ", r$arquivos[["avulsas_reservas"]], "  <- mesa\n", sep = "")

cat("\nNo banco:\n")
print(DBI::dbGetQuery(con,
  "select (select valor from ambiente)                            as carimbo,
          (select count(*)::int from programas)                   as programas,
          (select count(*)::int from programas where tipo = 'centro') as centros,
          (select count(*)::int from programas where login like 'credencial-%') as avulsas,
          (select count(*)::int from credenciais where ativa)     as ativas,
          (select count(*)::int from credenciais where not ativa) as reservas"))

cat("\nChapa:\n")
print(DBI::dbGetQuery(con, "select numero, nome from chapas order by numero"))

cat("\nUrna:\n")
imprimir_situacao(situacao_urna(con))

DBI::dbDisconnect(con)
cat("\nPronto. A urna está FECHADA: abra pelo painel na hora da votação.\n")
