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

test_that("carga deixa a credencial 1 ativa e as reservas 2 e 3 inativas", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  carregar_programas(con, programas_sinteticos(4))
  cred <- DBI::dbGetQuery(con,
    "select programa_id, ordem, ativa from credenciais order by programa_id, ordem")

  expect_true(all(cred$ativa[cred$ordem == 1]))
  expect_false(any(cred$ativa[cred$ordem != 1]))
  expect_equal(as.vector(table(cred$programa_id[cred$ativa])), rep(1L, 4))
})

# ---- trocar_credencial() -------------------------------------------------

test_that("trocar_credencial passa da 1 para a 2 e da 2 para a 3", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  ids <- credenciais_de(con, "prog01")

  r <- trocar_credencial(con, "prog01")
  expect_true(r$ok)
  expect_equal(r$ordem, 2)
  expect_equal(r$credencial_id, ids[2])
  expect_equal(credencial_ativa(con, "prog01"), 2)

  expect_equal(trocar_credencial(con, "prog01")$ordem, 3)
  expect_equal(credencial_ativa(con, "prog01"), 3)

  # os outros programas não mudam
  expect_equal(credencial_ativa(con, "prog02"), 1)
})

test_that("trocar_credencial recusa quando não há mais reserva", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  trocar_credencial(con, "prog01")
  trocar_credencial(con, "prog01")
  r <- trocar_credencial(con, "prog01")
  expect_false(r$ok)
  expect_equal(r$motivo, "sem_reserva")
  expect_equal(credencial_ativa(con, "prog01"), 3)   # nada mudou
})

test_that("trocar_credencial nunca volta a uma credencial já usada", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  # a 2 foi ativa e trocada pela 3: não há como voltar para a 1 nem para a 2
  trocar_credencial(con, "prog01")
  trocar_credencial(con, "prog01")
  expect_equal(trocar_credencial(con, "prog01")$motivo, "sem_reserva")
  expect_false(any(DBI::dbGetQuery(con,
    "select ativa from credenciais where programa_id = 'prog01' and ordem < 3")$ativa))
})

test_that("trocar_credencial recusa se o programa já votou", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  expect_true(registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")$ok)
  r <- trocar_credencial(con, "prog01")
  expect_false(r$ok)
  expect_equal(r$motivo, "ja_votou")
  expect_equal(credencial_ativa(con, "prog01"), 1)
})

test_that("trocar_credencial recusa programa inexistente", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  expect_equal(trocar_credencial(con, "nao-existe")$motivo, "programa_inexistente")
})

test_that("trocar_credencial registra no log, sem senha nem hash", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  saida <- carregar_programas(con, programas_sinteticos(2))

  trocar_credencial(con, "prog001")

  log <- DBI::dbGetQuery(con,
    "select detalhe from log where evento = 'credencial_trocada'")
  expect_equal(nrow(log), 1)
  expect_match(log$detalhe, "prog001")

  tudo <- toupper(gsub("-", "",
    paste(unlist(DBI::dbGetQuery(con, "select * from log")), collapse = " ")))
  for (s in normalizar_senha(saida$senha)) expect_false(grepl(s, tudo, fixed = TRUE))
  expect_false(grepl("$", paste(DBI::dbGetQuery(con, "select detalhe from log")$detalhe,
                                collapse = " "), fixed = TRUE))
})

test_that("carga recusa lista com login repetido e nao grava nada", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  p <- programas_sinteticos(3)
  p$login[3] <- p$login[1]

  expect_error(carregar_programas(con, p), "logins repetidos")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0)
})
