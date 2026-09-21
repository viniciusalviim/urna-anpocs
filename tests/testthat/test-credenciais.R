# Etapa 2 — credenciais.

# O sodium usa scrypt; o formato exato do hash nao importa para nos.
# O que importa: tem cara de hash (comeca com "$" e e longo) e nao contem a
# senha.
parece_hash <- function(h) grepl("^\\$", h) & nchar(h) > 50

test_that("senha tem formato XXXX-XXXX e nenhum caractere ambiguo", {
  s <- replicate(300, gerar_senha())
  expect_true(all(grepl("^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$", s)))
})

test_that("o hash nao contem a senha e confere corretamente", {
  s <- gerar_senha()
  h <- hash_senha(s)

  expect_true(parece_hash(h))
  expect_false(grepl(normalizar_senha(s), h, fixed = TRUE))
  expect_true(verificar_senha(s, h))
  expect_false(verificar_senha("AAAA-AAAA", h))
})

test_that("digitacao tolerante: minusculas, sem hifen, com espacos", {
  h <- hash_senha("K7PM-3XWQ")

  for (v in c("K7PM-3XWQ", "k7pm-3xwq", "K7PM3XWQ", " k7pm 3xwq ")) {
    expect_true(verificar_senha(v, h))
  }
  expect_false(verificar_senha("K7PM-3XW", h))     # faltando um caractere
  expect_false(verificar_senha("", h))
  expect_false(verificar_senha(NA, h))
  expect_false(verificar_senha("K7PM-3XWQ", "isto nao e um hash"))
})

test_that("carga cria os programas e 3 credenciais cada, sem senha em texto no banco", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  saida <- carregar_programas(con, programas_sinteticos(5))

  expect_equal(nrow(saida), 15)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 5)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from credenciais")$n, 15)

  hashes <- DBI::dbGetQuery(con, "select senha_hash from credenciais")$senha_hash
  expect_true(all(parece_hash(hashes)))
  expect_false(any(normalizar_senha(saida$senha) %in% hashes))
  expect_length(unique(saida$senha), 15)
})

test_that("cada senha abre a sua credencial e nenhuma outra", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  saida <- carregar_programas(con, programas_sinteticos(2))
  cred <- DBI::dbGetQuery(con,
    "select p.login, c.ordem, c.senha_hash
       from credenciais c join programas p on p.id = c.programa_id")

  for (i in seq_len(nrow(saida))) {
    alvo <- cred$login == saida$login[i] & cred$ordem == saida$ordem[i]
    expect_true(verificar_senha(saida$senha[i], cred$senha_hash[alvo]))
    for (h in cred$senha_hash[!alvo]) {
      expect_false(verificar_senha(saida$senha[i], h))
    }
  }
})

test_that("carga se recusa a rodar duas vezes no mesmo banco", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  carregar_programas(con, programas_sinteticos(3))
  expect_error(carregar_programas(con, programas_sinteticos(3)), "ja tem")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from credenciais")$n, 9)
})

test_that("carga recusa lista com login repetido e nao grava nada", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  p <- programas_sinteticos(3)
  p$login[3] <- p$login[1]

  expect_error(carregar_programas(con, p), "logins repetidos")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0)
})
