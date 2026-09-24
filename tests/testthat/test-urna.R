# Abrir e encerrar a urna. As mesmas funções servem aos scripts da rodada e,
# depois, ao painel do mesário.

estado_urna <- function(con) {
  DBI::dbGetQuery(con, "select estado, aberta_em, encerrada_em from urna")
}

test_that("abrir_urna: fechada -> aberta, grava a hora e registra no log", {
  con <- banco_limpo(estado = "fechada"); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con, "update urna set aberta_em = null")

  r <- abrir_urna(con)
  expect_true(r$ok)
  u <- estado_urna(con)
  expect_equal(u$estado, "aberta")
  expect_false(is.na(u$aberta_em))
  expect_true(is.na(u$encerrada_em))
  expect_equal(DBI::dbGetQuery(con,
    "select count(*)::int as n from log where evento = 'urna_aberta'")$n, 1)
})

test_that("abrir_urna recusa urna já aberta ou já encerrada", {
  con <- banco_limpo(estado = "aberta"); on.exit(DBI::dbDisconnect(con))
  r <- abrir_urna(con)
  expect_false(r$ok)
  expect_equal(r$motivo, "ja_aberta")

  expect_true(encerrar_urna(con)$ok)
  r <- abrir_urna(con)
  expect_false(r$ok)
  expect_equal(r$motivo, "ja_encerrada")
  expect_equal(estado_urna(con)$estado, "encerrada")
})

test_that("encerrar_urna: aberta -> encerrada, grava a hora e confere integridade", {
  con <- banco_limpo(estado = "aberta"); on.exit(DBI::dbDisconnect(con))
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
  registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "abstencao")

  r <- encerrar_urna(con)
  expect_true(r$ok)
  expect_true(r$integridade$ok)
  expect_equal(r$integridade$votantes, 2)

  u <- estado_urna(con)
  expect_equal(u$estado, "encerrada")
  expect_false(is.na(u$encerrada_em))

  log <- DBI::dbGetQuery(con,
    "select detalhe from log where evento = 'urna_encerrada'")$detalhe
  expect_length(log, 1)
  expect_match(log, "votantes=2")
  expect_match(log, "votos=2")
  expect_match(log, "integridade=ok")
})

test_that("encerrar_urna recusa urna fechada ou já encerrada", {
  con <- banco_limpo(estado = "fechada"); on.exit(DBI::dbDisconnect(con))
  expect_equal(encerrar_urna(con)$motivo, "nao_aberta")
  expect_equal(estado_urna(con)$estado, "fechada")

  abrir_urna(con); encerrar_urna(con)
  expect_equal(encerrar_urna(con)$motivo, "ja_encerrada")
})

test_that("depois de encerrada, ninguém vota", {
  con <- banco_limpo(estado = "aberta"); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  expect_equal(registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")$motivo,
               "urna_nao_aberta")
})

test_that("sem urna configurada, abrir e encerrar recusam", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  expect_equal(abrir_urna(con)$motivo, "urna_nao_configurada")
  expect_equal(encerrar_urna(con)$motivo, "urna_nao_configurada")
})

test_that("situacao_urna resume a urna sem nenhum conteúdo de voto", {
  con <- banco_limpo(estado = "aberta"); on.exit(DBI::dbDisconnect(con))
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "2")

  s <- situacao_urna(con)
  expect_type(s$votantes, "integer")   # bigint não imprime direito com cat()
  expect_output(imprimir_situacao(s), "Votantes       : 1\n", fixed = TRUE)
  expect_equal(s$estado, "aberta")
  expect_equal(s$modo, "teste")
  expect_equal(s$votantes, 1)
  expect_true(s$integridade_ok)
  expect_false(any(grepl("opcao|chapa|voto$", names(s))))
})
