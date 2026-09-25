# Senha do mesário (acesso ao painel).
#
# O hash fica em URNA_MESARIO_HASH, em hexadecimal: o hash do sodium tem
# vários "$", que o .Renviron poderia confundir com referência a variável.

test_that("o hash em hexadecimal confere a senha certa e só ela", {
  h <- codificar_hash_mesario("mesa-da-rodada-7")
  expect_match(h, "^([0-9a-f]{2})+$")
  expect_false(grepl("mesa", h, fixed = TRUE))

  expect_true(verificar_senha_mesario("mesa-da-rodada-7", h))
  expect_false(verificar_senha_mesario("mesa-da-rodada-8", h))
  expect_false(verificar_senha_mesario("MESA-DA-RODADA-7", h))   # sem tolerância
  expect_false(verificar_senha_mesario("", h))
  expect_false(verificar_senha_mesario(NA_character_, h))
  expect_false(verificar_senha_mesario(NULL, h))
})

test_that("sem hash configurado, ninguém entra", {
  expect_false(verificar_senha_mesario("qualquer", ""))
  expect_false(verificar_senha_mesario("qualquer", "nao-e-hexadecimal"))
  expect_false(verificar_senha_mesario("qualquer", "abc"))        # tamanho ímpar
  expect_false(verificar_senha_mesario("qualquer", "00ff"))       # hex, mas não é hash

  expect_false(mesario_configurado(""))
  expect_false(mesario_configurado("xyz"))
  expect_true(mesario_configurado(codificar_hash_mesario("x")))
})

test_that("por padrão lê URNA_MESARIO_HASH", {
  withr::local_envvar(c(URNA_MESARIO_HASH = codificar_hash_mesario("certa")))
  expect_true(mesario_configurado())
  expect_true(verificar_senha_mesario("certa"))
  expect_false(verificar_senha_mesario("errada"))

  withr::local_envvar(c(URNA_MESARIO_HASH = NA))
  expect_false(mesario_configurado())
  expect_false(verificar_senha_mesario("certa"))
})
