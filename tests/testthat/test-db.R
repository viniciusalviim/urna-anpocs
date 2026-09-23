# Conexao com o banco.

test_that("a conexao devolve os horarios no fuso de Brasilia", {
  con <- conectar(); on.exit(DBI::dbDisconnect(con))

  expect_equal(DBI::dbGetQuery(con, "show timezone")[[1]], "America/Sao_Paulo")

  agora <- DBI::dbGetQuery(con, "select now() as t")$t
  expect_equal(attr(agora, "tzone"), "America/Sao_Paulo")
})
