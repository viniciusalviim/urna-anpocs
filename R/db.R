# Urna ANPOCS 2026 — conexão com o banco
#
# Nenhuma credencial neste arquivo. Tudo vem de variáveis de ambiente:
# localmente pelo .Renviron, em produção pelas variáveis secretas do
# Posit Connect Cloud.

library(DBI)
library(RPostgres)
library(pool)

# Lê <prefixo>_HOST, <prefixo>_DB etc. O padrão, URNA_PG, é o que o app lê
# (no Connect Cloud) e o que os testes leem (no .Renviron, apontando para o
# dev). Os scripts da rodada de teste usam o prefixo URNA_TESTE_PG, para
# falar com o urna-teste sem mexer nas variáveis do dev.
parametros_pg <- function(prefixo = "URNA_PG") {
  v <- function(nome, padrao = "") Sys.getenv(paste0(prefixo, "_", nome), padrao)
  list(
    host     = v("HOST"),
    port     = as.integer(v("PORT", "5432")),
    dbname   = v("DB"),
    user     = v("USER"),
    password = v("PASSWORD"),
    sslmode  = v("SSLMODE", "require"),
    # O banco guarda o momento exato (timestamptz). Esta linha faz a conexao
    # DEVOLVER esses momentos no horario de Brasilia: log, comprovante,
    # painel e ata saem todos certos, sem conversao em cada tela.
    timezone = "America/Sao_Paulo"
  )
}

# Conexão única. Use nos scripts e nos testes.
# Sem as variáveis do prefixo pedido, para: nunca cai em outro prefixo.
conectar <- function(prefixo = "URNA_PG") {
  p <- parametros_pg(prefixo)
  if (!nzchar(p$host) || !nzchar(p$dbname)) {
    stop("Variáveis ", prefixo, "_HOST e ", prefixo, "_DB não configuradas ",
         "no .Renviron.", call. = FALSE)
  }
  do.call(DBI::dbConnect, c(list(RPostgres::Postgres()), p))
}

# Pool. Use no app Shiny.
conectar_pool <- function(min_size = 1, max_size = 10) {
  p <- parametros_pg()
  if (!nzchar(p$host) || !nzchar(p$dbname)) {
    stop("Variáveis URNA_PG_* não configuradas. Veja .Renviron.exemplo")
  }
  do.call(pool::dbPool, c(
    list(drv = RPostgres::Postgres(), minSize = min_size, maxSize = max_size),
    p
  ))
}

# Executa um arquivo .sql inteiro.
executar_sql <- function(con, caminho) {
  texto <- paste(readLines(caminho, warn = FALSE), collapse = "\n")
  texto <- gsub("--[^\n]*", "", texto)
  comandos <- trimws(strsplit(texto, ";", fixed = TRUE)[[1]])
  comandos <- comandos[nzchar(comandos)]
  for (cmd in comandos) DBI::dbExecute(con, cmd)
  invisible(length(comandos))
}


# ---------------------------------------------------------------------------
# Marcação de ambiente
#
# O carimbo fica DENTRO do banco, não no computador de quem se conecta.
# É o que impede os testes (que apagam tabelas) de rodarem contra o banco da
# eleição, mesmo que o .Renviron esteja errado.
# ---------------------------------------------------------------------------

AMBIENTES <- c("dev", "teste", "producao")

# Devolve "dev", "teste", "producao", ou NA se o banco nunca foi carimbado.
ambiente_do_banco <- function(con) {
  existe <- DBI::dbGetQuery(
    con, "select to_regclass('public.ambiente') is not null as existe")$existe
  if (!isTRUE(existe)) return(NA_character_)
  v <- DBI::dbGetQuery(con, "select valor from ambiente where id = 1")$valor
  if (length(v) == 0L) NA_character_ else v
}

# Carimba o banco. Só funciona uma vez: se já houver carimbo, ele é mantido.
# Trocar o carimbo exige apagar a tabela 'ambiente' na mão, de propósito.
marcar_ambiente <- function(con, valor) {
  stopifnot(length(valor) == 1L, valor %in% AMBIENTES)

  DBI::dbExecute(con, "
    create table if not exists ambiente (
      id        smallint primary key default 1 check (id = 1),
      valor     text not null check (valor in ('dev','teste','producao')),
      criado_em timestamptz not null default now()
    )")

  DBI::dbExecute(con,
    "insert into ambiente (id, valor) values (1, $1)
     on conflict (id) do nothing", list(valor))

  atual <- ambiente_do_banco(con)
  if (!identical(atual, valor)) {
    warning("Este banco JA estava carimbado como '", atual,
            "'. O carimbo nao foi alterado.")
  }
  invisible(atual)
}

# Para tudo se o carimbo do banco não estiver entre os esperados.
# Não apaga nada: só confere.
exigir_ambiente <- function(con, esperado) {
  amb <- ambiente_do_banco(con)
  if (is.na(amb)) {
    stop("Este banco nao tem carimbo de ambiente. Nada foi feito.", call. = FALSE)
  }
  if (!amb %in% esperado) {
    stop("PARADO. Este banco esta carimbado como '", amb, "', e esta ",
         "operacao so roda em: ", paste0("'", esperado, "'", collapse = " ou "),
         ". Nada foi feito.", call. = FALSE)
  }
  invisible(amb)
}

# ---------------------------------------------------------------------------
# URNA_AMBIENTE contra o carimbo
#
# No Connect Cloud, URNA_AMBIENTE diz onde o app acha que está ('teste' ou
# 'producao'). O carimbo diz onde ele está de fato. Se não baterem, ou se a
# variável faltar, o app não deixa ninguém votar: pega a urna de produção
# apontando para o banco de teste, e o contrário.
# ---------------------------------------------------------------------------

configuracao_ok <- function(variavel, carimbo) {
  length(variavel) == 1L && length(carimbo) == 1L &&
    !is.na(variavel) && !is.na(carimbo) &&
    nzchar(variavel) && identical(variavel, carimbo)
}

conferir_configuracao <- function(con, variavel = Sys.getenv("URNA_AMBIENTE")) {
  configuracao_ok(variavel, ambiente_do_banco(con))
}
