# Leituras do painel: só contagens e horas, nunca conteúdo de voto.

test_that("listar_programas mostra login, nome, credencial ativa, voto e hora", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
  trocar_credencial(con, "prog02")

  p <- listar_programas(con)
  expect_equal(nrow(p), 3)
  expect_equal(p$login, c("teste-01", "teste-02", "teste-03"))
  expect_equal(p$nome_oficial[1], "Programa de Teste 1")
  expect_equal(p$credencial_ativa, c(1L, 2L, 1L))
  expect_equal(p$votou, c(TRUE, FALSE, FALSE))
  expect_false(is.na(p$votado_em[1]))
  expect_true(all(is.na(p$votado_em[2:3])))
  expect_true(all(p$apto))

  # nenhuma coluna de voto
  expect_false(any(grepl("opcao|chapa|voto$", names(p))))
})

test_that("listar_programas mostra inapto", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con, "update programas set apto = false where id = 'prog03'")
  expect_equal(listar_programas(con)$apto, c(TRUE, TRUE, FALSE))
})

test_that("entrou_sem_votar: login aceito depois da abertura e sem voto", {
  con <- banco_limpo(estado = "fechada"); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con, "update urna set aberta_em = null")

  # login antes da abertura não conta
  registrar_log(con, "login_ok", "prog03")
  abrir_urna(con)

  registrar_log(con, "login_ok", "prog01")
  registrar_log(con, "login_ok", "prog02")
  registrar_log(con, "login_falhou", "prog03")
  registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "2")

  p <- listar_programas(con)
  expect_equal(p$entrou_sem_votar, c(TRUE, FALSE, FALSE))
})

test_that("contagem_votacao: aptos, votantes e integridade", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con, "update programas set apto = false where id = 'prog03'")
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "abstencao")

  c <- contagem_votacao(con)
  expect_equal(c$aptos, 2L)
  expect_equal(c$votantes, 1L)
  expect_true(c$integridade_ok)
  expect_type(c$aptos, "integer")
  expect_false(any(grepl("opcao|chapa", names(c))))
})
