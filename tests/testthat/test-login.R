# Etapa 3a — login.

# 3 programas com senhas de verdade (hash), urna no estado pedido, 1 chapa.
preparar_login <- function(estado = "aberta") {
  con <- banco_vazio()
  senhas <- carregar_programas(con, programas_sinteticos(3))
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao)
     values (1, $1, 'teste', true)", list(estado))
  DBI::dbExecute(con,
    "insert into chapas (numero, nome, membros) values (1, 'Chapa Um', '[]'::jsonb)")
  list(con = con, senhas = senhas)
}

senha_de <- function(s, login, ordem) {
  s$senha[s$login == login & s$ordem == ordem]
}

test_that("login certo entra, com qualquer uma das tres credenciais", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  ids <- DBI::dbGetQuery(b$con,
    "select id from credenciais where programa_id = 'prog001' order by ordem")$id

  for (o in 1:3) {
    r <- autenticar(b$con, "teste-001", senha_de(b$senhas, "teste-001", o))
    expect_true(r$ok)
    expect_equal(r$programa_id, "prog001")
    expect_equal(r$credencial_id, ids[o])
  }
})

test_that("login inexistente e senha errada dao a mesma resposta", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  errada     <- autenticar(b$con, "teste-001", "AAAA-AAAA")
  inexistente <- autenticar(b$con, "nao-existe", "AAAA-AAAA")
  vazio      <- autenticar(b$con, "", "AAAA-AAAA")

  expect_false(errada$ok)
  expect_equal(errada$motivo, "credenciais_invalidas")
  expect_identical(errada, inexistente)
  expect_identical(errada, vazio)
})

test_that("senha de um programa nao abre outro", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  r <- autenticar(b$con, "teste-002", senha_de(b$senhas, "teste-001", 1))
  expect_equal(r$motivo, "credenciais_invalidas")
})

test_that("digitacao tolerante no login e na senha", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  s <- senha_de(b$senhas, "teste-001", 1)
  r <- autenticar(b$con, "  TESTE-001 ", tolower(gsub("-", "", s)))
  expect_true(r$ok)
})

test_that("com a urna fora de 'aberta', ninguem entra", {
  for (estado in c("fechada", "encerrada")) {
    b <- preparar_login(estado)
    r <- autenticar(b$con, "teste-001", senha_de(b$senhas, "teste-001", 1))
    expect_equal(r$motivo, "urna_nao_aberta")
    DBI::dbDisconnect(b$con)
  }
})

test_that("'ja votou' so aparece depois da senha certa", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  r <- autenticar(b$con, "teste-001", senha_de(b$senhas, "teste-001", 1))
  expect_true(registrar_voto(b$con, r$programa_id, r$credencial_id, "1")$ok)

  # com senha certa, de qualquer credencial do programa: ja votou
  for (o in 1:3) {
    r2 <- autenticar(b$con, "teste-001", senha_de(b$senhas, "teste-001", o))
    expect_equal(r2$motivo, "ja_votou")
  }
  # com senha errada: nao revela nada
  expect_equal(autenticar(b$con, "teste-001", "AAAA-AAAA")$motivo,
               "credenciais_invalidas")
})

test_that("programa inapto nao entra", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  DBI::dbExecute(b$con, "update programas set apto = false where id = 'prog002'")
  r <- autenticar(b$con, "teste-002", senha_de(b$senhas, "teste-002", 1))
  expect_equal(r$motivo, "programa_inapto")
})

test_that("o log registra as tentativas mas nunca o que foi digitado", {
  b <- preparar_login(); on.exit(DBI::dbDisconnect(b$con))

  s <- senha_de(b$senhas, "teste-001", 1)
  autenticar(b$con, "teste-001", "ZZZZ-9999")   # senha errada
  autenticar(b$con, s, s)                       # senha colada no campo de login
  autenticar(b$con, "teste-001", s)             # certo

  log <- DBI::dbGetQuery(b$con,
    "select evento, detalhe from log where evento like 'login%' order by id")

  expect_equal(log$evento, c("login_falhou", "login_falhou", "login_ok"))
  expect_equal(log$detalhe, c("prog001", NA, "prog001"))

  tudo <- paste(unlist(DBI::dbGetQuery(b$con, "select * from log")), collapse = " ")
  expect_false(grepl(normalizar_senha(s), toupper(gsub("-", "", tudo)), fixed = TRUE))
  expect_false(grepl("ZZZZ", tudo, fixed = TRUE))
})
