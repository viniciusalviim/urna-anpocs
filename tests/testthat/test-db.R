# Conexao com o banco.

test_that("a conexao devolve os horarios no fuso de Brasilia", {
  con <- conectar(); on.exit(DBI::dbDisconnect(con))

  expect_equal(DBI::dbGetQuery(con, "show timezone")[[1]], "America/Sao_Paulo")

  agora <- DBI::dbGetQuery(con, "select now() as t")$t
  expect_equal(attr(agora, "tzone"), "America/Sao_Paulo")
})

# ---- variaveis por prefixo -------------------------------------------------

test_that("parametros_pg le as variaveis do prefixo pedido", {
  withr::local_envvar(c(
    URNA_TESTE_PG_HOST = "host-da-rodada.example", URNA_TESTE_PG_DB = "rodada",
    URNA_TESTE_PG_USER = "u", URNA_TESTE_PG_PASSWORD = "p",
    URNA_TESTE_PG_PORT = "6543", URNA_TESTE_PG_SSLMODE = "verify-full"))

  p <- parametros_pg("URNA_TESTE_PG")
  expect_equal(p$host, "host-da-rodada.example")
  expect_equal(p$dbname, "rodada")
  expect_equal(p$port, 6543L)
  expect_equal(p$sslmode, "verify-full")
  expect_equal(p$timezone, "America/Sao_Paulo")

  # sem prefixo, continua lendo URNA_PG_* (o app e os testes)
  expect_equal(parametros_pg()$host, Sys.getenv("URNA_PG_HOST"))
})

test_that("sem as variaveis do prefixo, conectar para e nao cai em URNA_PG_*", {
  withr::local_envvar(c(URNA_NADA_PG_HOST = NA, URNA_NADA_PG_DB = NA))
  expect_error(conectar("URNA_NADA_PG"), "URNA_NADA_PG_HOST")
})

# ---- carimbo de ambiente ---------------------------------------------------

test_that("exigir_ambiente aceita o carimbo certo e recusa os outros", {
  con <- conectar(); on.exit(DBI::dbDisconnect(con))

  expect_silent(exigir_ambiente(con, "dev"))
  expect_silent(exigir_ambiente(con, c("dev", "teste")))
  expect_error(exigir_ambiente(con, "teste"), "carimbado como 'dev'")
  expect_error(exigir_ambiente(con, "producao"), "carimbado como 'dev'")
})

test_that("marcar_ambiente aceita os tres valores e mais nenhum", {
  expect_equal(AMBIENTES, c("dev", "teste", "producao"))
  con <- conectar(); on.exit(DBI::dbDisconnect(con))
  expect_error(marcar_ambiente(con, "outro"))
})

# ---- URNA_AMBIENTE contra o carimbo ----------------------------------------

test_that("configuracao_ok exige variavel preenchida e igual ao carimbo", {
  expect_true(configuracao_ok("producao", "producao"))
  expect_true(configuracao_ok("teste", "teste"))

  expect_false(configuracao_ok("teste", "producao"))
  expect_false(configuracao_ok("producao", "teste"))
  expect_false(configuracao_ok("", "producao"))          # variavel ausente
  expect_false(configuracao_ok("producao", NA_character_)) # banco sem carimbo
  expect_false(configuracao_ok("", NA_character_))
  expect_false(configuracao_ok(" producao", "producao"))
})

test_that("conferir_configuracao compara URNA_AMBIENTE com o banco", {
  con <- conectar(); on.exit(DBI::dbDisconnect(con))

  expect_true(conferir_configuracao(con, "dev"))
  expect_false(conferir_configuracao(con, "producao"))
  expect_false(conferir_configuracao(con, ""))

  withr::local_envvar(c(URNA_AMBIENTE = "dev"))
  expect_true(conferir_configuracao(con))
  withr::local_envvar(c(URNA_AMBIENTE = NA))
  expect_false(conferir_configuracao(con))
})
