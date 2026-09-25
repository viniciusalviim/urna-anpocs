# Fechamento com embaralhamento (seção 6) e apuração.
# Invariantes 9, 10 e 11.

# Urna com os 3 programas da semente votando: 1, 1 e abstenção.
urna_votada <- function() {
  con <- banco_limpo(estado = "aberta")
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
  registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "1")
  registrar_voto(con, "prog03", credenciais_de(con, "prog03")[1], "abstencao")
  con
}

votos_como_estao <- function(con) {
  DBI::dbGetQuery(con, "select id::text as id, opcao from votos order by id")
}

# ---- embaralhar_votos() ----------------------------------------------------

test_that("embaralhar recusa urna fechada ou aberta", {
  con <- banco_limpo(estado = "fechada"); on.exit(DBI::dbDisconnect(con))
  expect_equal(embaralhar_votos(con)$motivo, "urna_nao_encerrada")
  abrir_urna(con)
  expect_equal(embaralhar_votos(con)$motivo, "urna_nao_encerrada")
})

test_that("embaralhar recusa se a integridade não bate, e não mexe em nada", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  # um voto sem votante: incidente
  DBI::dbExecute(con, "insert into votos (id, opcao) values (gen_random_uuid(), '2')")
  ordem <- DBI::dbGetQuery(con, "select id::text as id from votos")$id
  encerrar_urna(con)

  expect_equal(embaralhar_votos(con)$motivo, "integridade_divergente")
  expect_equal(DBI::dbGetQuery(con, "select id::text as id from votos")$id, ordem)
  expect_false(votos_embaralhados(con))
})

test_that("embaralhar: mesmos votos, ordem nova, integridade antes e depois", {
  con <- banco_limpo(estado = "aberta"); on.exit(DBI::dbDisconnect(con))

  # 60 programas e 60 votos de verdade, pela transação do voto
  DBI::dbExecute(con,
    "insert into programas (id, nome_oficial, tipo, login)
     select 'x' || g, 'Extra ' || g, 'ppg', 'extra-' || g from generate_series(1, 57) g")
  DBI::dbExecute(con,
    "insert into credenciais (programa_id, ordem, senha_hash, ativa)
     select 'x' || g, 1, 'h', true from generate_series(1, 57) g")
  progs <- DBI::dbGetQuery(con, "select id from programas order by id")$id
  for (i in seq_along(progs)) {
    cred <- DBI::dbGetQuery(con,
      "select id from credenciais where programa_id = $1 and ativa", list(progs[i]))$id
    expect_true(registrar_voto(con, progs[i], cred, if (i %% 3) "1" else "2")$ok)
  }
  ordem_de_voto <- DBI::dbGetQuery(con, "select id::text as id from votos")$id
  antes <- votos_como_estao(con)
  encerrar_urna(con)

  r <- embaralhar_votos(con)
  expect_true(r$ok)
  expect_true(r$antes$ok)
  expect_true(r$depois$ok)
  expect_equal(r$depois$votos, 60L)

  expect_equal(votos_como_estao(con), antes)          # mesmos votos
  expect_false(identical(                             # outra ordem física
    DBI::dbGetQuery(con, "select id::text as id from votos")$id, ordem_de_voto))
})

test_that("INV 4 — depois de embaralhar, votos continua só com id e opcao", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  expect_true(embaralhar_votos(con)$ok)

  cols <- DBI::dbGetQuery(con,
    "select column_name, data_type, is_nullable, column_default
       from information_schema.columns
      where table_name = 'votos' order by column_name")
  expect_equal(cols$column_name, c("id", "opcao"))
  expect_equal(cols$data_type, c("uuid", "text"))
  expect_equal(cols$is_nullable, c("NO", "NO"))
  expect_true(all(is.na(cols$column_default)))

  pk <- DBI::dbGetQuery(con,
    "select count(*)::int as n from information_schema.table_constraints
      where table_name = 'votos' and constraint_type = 'PRIMARY KEY'")$n
  expect_equal(pk, 1L)
  expect_error(DBI::dbExecute(con, "insert into votos (id, opcao) values (gen_random_uuid(), null)"))
})

test_that("embaralhar roda uma vez só e registra no log", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)

  expect_false(votos_embaralhados(con))
  expect_true(embaralhar_votos(con)$ok)
  expect_true(votos_embaralhados(con))
  expect_equal(embaralhar_votos(con)$motivo, "ja_embaralhado")

  log <- DBI::dbGetQuery(con,
    "select detalhe from log where evento = 'votos_embaralhados'")$detalhe
  expect_length(log, 1)
  expect_match(log, "votos=3")
  expect_false(grepl("abstencao|opcao", log))
})

test_that("depois de limpar a sessão da rodada, embaralhar volta a ser possível", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con); embaralhar_votos(con)
  limpar_votos(con, withr::local_tempdir(), ambientes = "dev")
  expect_false(votos_embaralhados(con))

  abrir_urna(con)
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "2")
  encerrar_urna(con)
  expect_true(embaralhar_votos(con)$ok)
})

# ---- apurar() --------------------------------------------------------------

test_that("INV 9 — apurar recusa antes do encerramento, em qualquer modo", {
  for (modo in c("teste", "oficial")) {
    con <- urna_votada()
    DBI::dbExecute(con, "update urna set modo = $1", list(modo))
    expect_equal(apurar(con)$motivo, "urna_nao_encerrada", info = modo)
    expect_null(apurar(con)$tabela)
    DBI::dbDisconnect(con)
  }
})

test_that("apurar recusa antes do embaralhamento", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  expect_equal(apurar(con)$motivo, "votos_nao_embaralhados")
})

test_that("apurar: total por chapa (inclusive zero), abstenções, votantes e aptos", {
  con <- urna_votada(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con); embaralhar_votos(con)

  a <- apurar(con)
  expect_true(a$ok)
  expect_equal(a$tabela$opcao, c("1", "2", "abstencao"))
  expect_equal(a$tabela$nome,  c("Chapa Um", "Chapa Dois", "Abstenção"))
  expect_equal(a$tabela$votos, c(2L, 0L, 1L))
  expect_equal(a$total_votos, 3L)
  expect_equal(a$votantes, 3L)
  expect_equal(a$aptos, 3L)
  expect_true(a$integridade_ok)
  expect_equal(sum(a$tabela$votos), a$votantes)
})

test_that("apurar sem abstenção permitida não mostra a linha de abstenção", {
  con <- banco_limpo(estado = "aberta", permite_abstencao = FALSE)
  on.exit(DBI::dbDisconnect(con))
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "2")
  encerrar_urna(con); embaralhar_votos(con)

  a <- apurar(con)
  expect_equal(a$tabela$opcao, c("1", "2"))
  expect_equal(a$tabela$votos, c(0L, 1L))
})

# ---- INV 9: nenhum outro caminho de código lê a tabela votos ----------------

# Funções (ou arquivos inteiros de app) que citam a tabela votos em SQL.
funcoes_que_tocam_votos <- function(arquivo) {
  padrao <- "(?i)\\b(from|into|join|table|update)\\s+votos\\b"
  exprs <- parse(arquivo, keep.source = FALSE)
  achadas <- character()
  for (e in exprs) {
    texto <- paste(deparse(e), collapse = "\n")
    if (!grepl(padrao, texto, perl = TRUE)) next
    nome <- if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") &&
                is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))) {
      as.character(e[[2]])
    } else {
      paste0("<codigo solto em ", basename(arquivo), ">")
    }
    achadas <- c(achadas, nome)
  }
  achadas
}

test_that("INV 9 — só funções conhecidas citam a tabela votos", {
  raiz <- file.path("..", "..")
  arquivos <- c(list.files(file.path(raiz, "R"), "\\.R$", full.names = TRUE),
                file.path(raiz, "urna", "app.R"),
                file.path(raiz, "painel", "app.R"))
  # os dois apps têm de existir e ser lidos
  expect_true(file.exists(file.path(raiz, "urna", "app.R")))
  expect_true(file.exists(file.path(raiz, "painel", "app.R")))

  achadas <- unlist(lapply(arquivos, funcoes_que_tocam_votos))
  permitidas <- c("conferir_integridade",   # só count(*)
                  "registrar_voto",         # só insert
                  "embaralhar_votos",       # só com a urna encerrada
                  "apurar")                 # só com a urna encerrada
  expect_setequal(achadas, permitidas)
})
