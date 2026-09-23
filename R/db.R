# Urna ANPOCS 2026 — conexão com o banco
#
# Nenhuma credencial neste arquivo. Tudo vem de variáveis de ambiente:
# localmente pelo .Renviron, em produção pelas variáveis secretas do
# Posit Connect Cloud.

library(DBI)
library(RPostgres)
library(pool)

parametros_pg <- function() {
  list(
    host     = Sys.getenv("URNA_PG_HOST"),
    port     = as.integer(Sys.getenv("URNA_PG_PORT", "5432")),
    dbname   = Sys.getenv("URNA_PG_DB"),
    user     = Sys.getenv("URNA_PG_USER"),
    password = Sys.getenv("URNA_PG_PASSWORD"),
    sslmode  = Sys.getenv("URNA_PG_SSLMODE", "require"),
    # O banco guarda o momento exato (timestamptz). Esta linha faz a conexao
    # DEVOLVER esses momentos no horario de Brasilia: log, comprovante,
    # painel e ata saem todos certos, sem conversao em cada tela.
    timezone = "America/Sao_Paulo"
  )
}

# Conexão única. Use nos scripts e nos testes.
conectar <- function() {
  p <- parametros_pg()
  if (!nzchar(p$host) || !nzchar(p$dbname)) {
    stop("Variáveis URNA_PG_* não configuradas. Veja .Renviron.exemplo")
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

# Devolve "dev", "producao", ou NA se o banco nunca foi carimbado.
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
  stopifnot(valor %in% c("dev", "producao"))

  DBI::dbExecute(con, "
    create table if not exists ambiente (
      id        smallint primary key default 1 check (id = 1),
      valor     text not null check (valor in ('dev','producao')),
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
