# Cédula: leitura das chapas e descrição da opção digitada.
# A tela em si é testada na mão; aqui fica a lógica que ela usa.

# Cédula montada à mão, sem banco, para os testes de descrever_opcao().
cedula_exemplo <- function(permite_abstencao = TRUE) {
  list(
    permite_abstencao = permite_abstencao,
    chapas = list(
      "1" = list(nome = "Chapa Um",
                 membros = data.frame(nome  = c("Fulana", "Sicrano"),
                                      cargo = c("Presidencia", "Tesouraria"))),
      "12" = list(nome = "Chapa Doze",
                  membros = data.frame(nome = "Beltrano", cargo = "Presidencia"))
    )
  )
}

# ---- ler_cedula() --------------------------------------------------------

test_that("ler_cedula lê as chapas com membros e cargos, na ordem do cadastro", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  DBI::dbExecute(con,
    "update chapas set membros =
       '[{\"nome\":\"Fulana\",\"cargo\":\"Presidencia\"},
         {\"nome\":\"Ciclana\",\"cargo\":\"Conselho Fiscal\"}]'::jsonb
      where numero = 1")

  ced <- ler_cedula(con)

  expect_true(ced$permite_abstencao)
  expect_equal(names(ced$chapas), c("1", "2"))
  expect_equal(ced$chapas[["1"]]$nome, "Chapa Um")
  expect_equal(ced$chapas[["1"]]$membros$nome,  c("Fulana", "Ciclana"))
  expect_equal(ced$chapas[["1"]]$membros$cargo, c("Presidencia", "Conselho Fiscal"))
  expect_equal(ced$chapas[["2"]]$membros$nome, "Beltrano")
})

test_that("ler_cedula respeita permite_abstencao = FALSE", {
  con <- banco_limpo(permite_abstencao = FALSE); on.exit(DBI::dbDisconnect(con))
  expect_false(ler_cedula(con)$permite_abstencao)
})

test_that("ler_cedula sem urna configurada devolve abstenção proibida", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  ced <- ler_cedula(con)
  expect_false(ced$permite_abstencao)
  expect_length(ced$chapas, 0)
})

# ---- descrever_opcao() ---------------------------------------------------

test_that("número existente é válido e traz nome e membros", {
  d <- descrever_opcao(cedula_exemplo(), "1")
  expect_equal(d$estado, "valida")
  expect_equal(d$opcao, "1")
  expect_equal(d$nome, "Chapa Um")
  expect_equal(d$membros$nome, c("Fulana", "Sicrano"))
  expect_equal(d$membros$cargo, c("Presidencia", "Tesouraria"))

  expect_equal(descrever_opcao(cedula_exemplo(), "12")$nome, "Chapa Doze")
})

test_that("número inexistente não é válido e não tem opção", {
  for (x in c("2", "3", "0", "99", "121")) {
    d <- descrever_opcao(cedula_exemplo(), x)
    expect_equal(d$estado, "inexistente", info = x)
    expect_null(d$opcao)
  }
})

test_that("campo vazio não é válido nem inexistente", {
  for (x in list("", "   ", NULL, NA_character_)) {
    d <- descrever_opcao(cedula_exemplo(), x)
    expect_equal(d$estado, "vazio")
    expect_null(d$opcao)
  }
})

test_that("zeros à esquerda e espaços são tolerados", {
  expect_equal(descrever_opcao(cedula_exemplo(), "01")$opcao, "1")
  expect_equal(descrever_opcao(cedula_exemplo(), " 1 ")$opcao, "1")
  expect_equal(descrever_opcao(cedula_exemplo(), "0012")$opcao, "12")
})

test_that("texto que não é número inteiro positivo é inexistente", {
  for (x in c("a", "1a", "1.5", "1,0", "-1", "+1", "1 2", "1e1",
              "99999999999999999999")) {
    expect_equal(descrever_opcao(cedula_exemplo(), x)$estado, "inexistente",
                 info = x)
  }
})

test_that("abstenção vale só quando permitida", {
  d <- descrever_opcao(cedula_exemplo(TRUE), "abstencao")
  expect_equal(d$estado, "valida")
  expect_equal(d$opcao, "abstencao")
  expect_equal(d$nome, "Abstenção")

  d <- descrever_opcao(cedula_exemplo(FALSE), "abstencao")
  expect_equal(d$estado, "inexistente")
  expect_null(d$opcao)
})

test_that("abstenção é aceita com ou sem acento, em qualquer caixa", {
  # O botão ABSTENÇÃO escreve TEXTO_ABSTENCAO no campo: tem de ser aceito.
  expect_equal(descrever_opcao(cedula_exemplo(), TEXTO_ABSTENCAO)$opcao, "abstencao")
  for (x in c("abstencao", "ABSTENCAO", "Abstencao",
              "abstenção", "ABSTENÇÃO", "Abstenção",
              "abstençao", "abstencão", " abstencao ")) {
    expect_equal(descrever_opcao(cedula_exemplo(), x)$opcao, "abstencao", info = x)
  }
})

test_that("'branco' não é mais uma opção da cédula", {
  expect_equal(descrever_opcao(cedula_exemplo(), "branco")$estado, "inexistente")
  expect_equal(descrever_opcao(cedula_exemplo(), "abst")$estado, "inexistente")
})

# ---- rótulo do botão -----------------------------------------------------

test_that("o botão diz o que confirma", {
  expect_equal(rotulo_confirma("1"),  "CONFIRMAR VOTO NA CHAPA 1")
  expect_equal(rotulo_confirma("12"), "CONFIRMAR VOTO NA CHAPA 12")
  expect_equal(rotulo_confirma("abstencao"), "CONFIRMAR ABSTENÇÃO")

  # o rótulo sai da mesma opção que vai para registrar_voto()
  d <- descrever_opcao(cedula_exemplo(), "012")
  expect_equal(rotulo_confirma(d$opcao), "CONFIRMAR VOTO NA CHAPA 12")
  d <- descrever_opcao(cedula_exemplo(), TEXTO_ABSTENCAO)
  expect_equal(rotulo_confirma(d$opcao), "CONFIRMAR ABSTENÇÃO")
})

# ---- as duas pontas batem ------------------------------------------------

test_that("toda opção válida na tela é aceita por registrar_voto()", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  ced <- ler_cedula(con)

  entradas <- c("1", "02", TEXTO_ABSTENCAO)
  programas <- c("prog01", "prog02", "prog03")
  for (i in seq_along(entradas)) {
    d <- descrever_opcao(ced, entradas[i])
    expect_equal(d$estado, "valida")
    r <- registrar_voto(con, programas[i],
                        credenciais_de(con, programas[i])[1], d$opcao)
    expect_true(r$ok, info = entradas[i])
  }
  expect_true(conferir_integridade(con)$ok)
})

test_that("número inexistente na tela também é recusado pelo banco", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  ced <- ler_cedula(con)
  expect_equal(descrever_opcao(ced, "3")$estado, "inexistente")
  expect_equal(registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "3")$motivo,
               "opcao_invalida")
})
