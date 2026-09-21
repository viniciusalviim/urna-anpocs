# Invariantes 1 a 6 do CLAUDE.md.
# Teste que quebra é sinal de que a mudança está errada, não de que o teste
# precisa de ajuste.

test_that("INV 1 — um programa vota no máximo uma vez", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  cred <- credenciais_de(con, "prog01")

  primeiro <- registrar_voto(con, "prog01", cred[1], "1")
  segundo  <- registrar_voto(con, "prog01", cred[1], "2")

  expect_true(primeiro$ok)
  expect_false(segundo$ok)
  expect_equal(segundo$motivo, "ja_votou")
  expect_equal(DBI::dbGetQuery(con, "select count(*) as n from votos")$n, 1)
})

test_that("INV 2 — a trava é por programa: as outras credenciais morrem junto", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  cred <- credenciais_de(con, "prog01")

  expect_true(registrar_voto(con, "prog01", cred[1], "1")$ok)
  expect_equal(registrar_voto(con, "prog01", cred[2], "2")$motivo, "ja_votou")
  expect_equal(registrar_voto(con, "prog01", cred[3], "1")$motivo, "ja_votou")

  # e não contamina os outros programas
  expect_true(registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "2")$ok)
})

test_that("INV 3 — votantes e votos batem sempre", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  for (p in c("prog01", "prog02", "prog03")) {
    registrar_voto(con, p, credenciais_de(con, p)[1], "1")
    expect_true(conferir_integridade(con)$ok)
  }
  # tentativas recusadas não desequilibram
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[2], "1")
  registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "99")
  expect_true(conferir_integridade(con)$ok)
  expect_equal(conferir_integridade(con)$votos, 3)
})

test_that("INV 4 — votos não tem tempo nem sequência", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  cols <- DBI::dbGetQuery(con,
    "select column_name, data_type, column_default
       from information_schema.columns
      where table_name = 'votos' order by column_name")

  expect_setequal(cols$column_name, c("id", "opcao"))
  expect_false(any(grepl("timestamp|date|time", cols$data_type)))
  expect_false(any(grepl("nextval", cols$column_default %||% "")))
})

test_that("INV 5 — nenhum voto entra com a urna fora de 'aberta'", {
  for (estado in c("fechada", "encerrada")) {
    con <- banco_limpo(estado = estado)
    r <- registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
    expect_false(r$ok)
    expect_equal(r$motivo, "urna_nao_aberta")
    expect_equal(DBI::dbGetQuery(con, "select count(*) as n from votos")$n, 0)
    DBI::dbDisconnect(con)
  }
})

test_that("INV 6 — recusa não grava nada e não devolve comprovante", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  r1 <- registrar_voto(con, "prog01", 999999, "1")          # credencial de outro
  r2 <- registrar_voto(con, "prog01", credenciais_de(con, "prog02")[1], "1")
  r3 <- registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "7")

  expect_equal(r1$motivo, "credencial_invalida")
  expect_equal(r2$motivo, "credencial_invalida")
  expect_equal(r3$motivo, "opcao_invalida")
  expect_null(r1$comprovante_id)

  expect_equal(DBI::dbGetQuery(con, "select count(*) as n from votantes")$n, 0)
  expect_equal(DBI::dbGetQuery(con, "select count(*) as n from votos")$n, 0)
})

test_that("branco só é aceito quando a urna permite", {
  con <- banco_limpo(permite_branco = TRUE)
  expect_true(registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "branco")$ok)
  DBI::dbDisconnect(con)

  con <- banco_limpo(permite_branco = FALSE)
  expect_equal(
    registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "branco")$motivo,
    "opcao_invalida")
  DBI::dbDisconnect(con)
})

test_that("o comprovante é único e legível", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  cods <- vapply(c("prog01", "prog02", "prog03"), function(p) {
    registrar_voto(con, p, credenciais_de(con, p)[1], "1")$comprovante_id
  }, character(1))

  expect_length(unique(cods), 3)
  expect_true(all(grepl("^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$", cods)))
  expect_false(any(grepl("[IO01l]", cods)))
})
