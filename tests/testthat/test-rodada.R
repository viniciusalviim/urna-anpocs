# Rodada de teste: programas da rodada e limpeza de votos entre sessões.
#
# Os testes rodam no banco de dev. limpar_votos() só aceita 'dev' aqui porque
# o teste pede explicitamente; os scripts da rodada usam o padrão, 'teste'.

test_that("programas_rodada: 60 logins rodada-01..60 e nomes de participante", {
  p <- programas_rodada(60)
  expect_equal(nrow(p), 60)
  expect_equal(p$login[c(1, 9, 60)], c("rodada-01", "rodada-09", "rodada-60"))
  expect_equal(p$nome_oficial[c(1, 60)],
               c("Participante da rodada 01", "Participante da rodada 60"))
  expect_equal(p$id[1], "rod01")
  expect_true(all(p$tipo == "ppg"))
  expect_false(anyDuplicated(p$login) > 0)
})

# ---- limpar_votos() ------------------------------------------------------

sessao_com_votos <- function() {
  con <- banco_limpo(estado = "aberta")
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
  registrar_voto(con, "prog02", credenciais_de(con, "prog02")[1], "abstencao")
  con
}

conta <- function(con, tabela) {
  DBI::dbGetQuery(con, paste("select count(*)::int as n from", tabela))$n
}

test_that("limpar_votos recusa urna aberta e não apaga nada", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()

  expect_error(limpar_votos(con, pasta, ambientes = "dev"), "aberta")
  expect_equal(conta(con, "votos"), 2)
  expect_equal(conta(con, "votantes"), 2)
  expect_length(list.files(pasta), 0)
})

test_that("limpar_votos recusa banco com carimbo diferente do pedido", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  pasta <- withr::local_tempdir()

  # o banco de dev não é 'teste': o padrão dos scripts recusa
  expect_error(limpar_votos(con, pasta), "carimbado como 'dev'")
  expect_equal(conta(con, "votos"), 2)
})

test_that("limpar_votos nunca aceita producao, nem se pedirem", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  expect_error(limpar_votos(con, withr::local_tempdir(),
                            ambientes = c("dev", "producao")), "producao")
  expect_equal(conta(con, "votos"), 2)
})

test_that("limpar_votos arquiva log, votantes e votos antes de apagar", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  n_log <- conta(con, "log")
  ids_votos <- DBI::dbGetQuery(con, "select id::text as id from votos")$id

  pasta <- withr::local_tempdir()
  quando <- as.POSIXct("2026-09-26 20:15:30", tz = "America/Sao_Paulo")
  r <- limpar_votos(con, pasta, ambientes = "dev", quando = quando)
  expect_true(r$ok)

  arq <- sort(list.files(pasta))
  expect_equal(arq, sort(c(
    "RODADA_arquivo_2026-09-26_201530_log.csv",
    "RODADA_arquivo_2026-09-26_201530_votantes.csv",
    "RODADA_arquivo_2026-09-26_201530_votos.csv")))

  lido <- function(sufixo) {
    read.csv(file.path(pasta, paste0("RODADA_arquivo_2026-09-26_201530_", sufixo, ".csv")),
             colClasses = "character")
  }
  expect_equal(nrow(lido("log")), n_log)
  expect_equal(sort(lido("votantes")$programa_id), c("prog01", "prog02"))

  votos <- lido("votos")
  expect_equal(names(votos), c("id", "opcao"))
  expect_setequal(votos$id, ids_votos)
  expect_equal(votos$id, sort(votos$id))           # ordenado pelo id aleatório
  expect_setequal(votos$opcao, c("1", "abstencao"))
})

test_that("limpar_votos apaga votos, votantes e log, mas não as credenciais", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  cred_antes <- DBI::dbGetQuery(con,
    "select id, senha_hash, ativa from credenciais order by id")

  limpar_votos(con, withr::local_tempdir(), ambientes = "dev")

  expect_equal(conta(con, "votos"), 0)
  expect_equal(conta(con, "votantes"), 0)
  expect_equal(DBI::dbGetQuery(con, "select evento from log")$evento, "votos_limpos")
  expect_equal(DBI::dbGetQuery(con,
    "select id, senha_hash, ativa from credenciais order by id"), cred_antes)
  expect_equal(conta(con, "chapas"), 2)

  u <- DBI::dbGetQuery(con, "select estado, aberta_em, encerrada_em, modo from urna")
  expect_equal(u$estado, "fechada")
  expect_true(is.na(u$aberta_em))
  expect_true(is.na(u$encerrada_em))
  expect_equal(u$modo, "teste")
})

test_that("várias sessões: encerrar, limpar, abrir, e as mesmas credenciais votam de novo", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()

  for (sessao in 1:2) {
    expect_true(encerrar_urna(con)$ok)
    limpar_votos(con, pasta, ambientes = "dev",
                 quando = Sys.time() + sessao)     # nomes de arquivo diferentes
    expect_true(abrir_urna(con)$ok)
    expect_true(registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "2")$ok)
    expect_true(conferir_integridade(con)$ok)
  }
  expect_length(list.files(pasta), 6)
})

test_that("limpar_votos não sobrescreve nem apaga um arquivo que já existe", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)
  pasta <- withr::local_tempdir()
  quando <- as.POSIXct("2026-09-26 20:15:30", tz = "America/Sao_Paulo")
  antigo <- file.path(pasta, "RODADA_arquivo_2026-09-26_201530_votos.csv")
  writeLines("arquivo de uma sessão anterior", antigo)

  expect_error(limpar_votos(con, pasta, ambientes = "dev", quando = quando),
               "Ja existem")
  expect_equal(readLines(antigo), "arquivo de uma sessão anterior")
  expect_equal(conta(con, "votos"), 2)
})

test_that("limpar_votos não apaga nada se não conseguir gravar os arquivos", {
  con <- sessao_com_votos(); on.exit(DBI::dbDisconnect(con))
  encerrar_urna(con)

  expect_error(limpar_votos(con, file.path(tempdir(), "pasta-que-nao-existe"),
                            ambientes = "dev"), "Nada foi")
  expect_equal(conta(con, "votos"), 2)
  expect_equal(conta(con, "votantes"), 2)
})
