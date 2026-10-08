# Etapa 2 — credenciais.

# O sodium usa scrypt; o formato exato do hash nao importa para nos.
# O que importa: tem cara de hash (comeca com "$" e e longo) e nao contem a
# senha.
parece_hash <- function(h) grepl("^\\$", h) & nchar(h) > 50

# Regra mudada por decisão do responsável (08/10): a senha passa a ser um
# PIN de 4 números. Antes eram 8 caracteres de um alfabeto sem ambíguos.

test_that("PIN tem 4 números, de 0000 a 9999", {
  p <- replicate(500, gerar_pin())
  expect_true(all(grepl("^[0-9]{4}$", p)))
})

test_that("PIN sorteado sem viés: cada um dos 10.000 valores tem a mesma chance", {
  # Dois bytes aleatórios dão 0 a 65535. Os valores de 60000 em diante são
  # descartados (sorteia-se de novo); de 0 a 59999, o resto por 10000 dá
  # cada PIN exatamente 6 vezes.
  todos <- pin_de_inteiro(0:65535)
  validos <- todos[!is.na(todos)]
  expect_equal(length(validos), 60000)
  expect_equal(sum(is.na(todos)), 65536 - 60000)
  expect_true(all(is.na(pin_de_inteiro(60000:65535))))
  contagem <- table(validos)
  expect_equal(length(contagem), 10000)
  expect_true(all(contagem == 6))
  expect_equal(pin_de_inteiro(c(0, 427, 9999, 10000, 59999)),
               c("0000", "0427", "9999", "0000", "9999"))
})

test_that("os 3 PINs de um programa são diferentes entre si", {
  for (i in 1:200) {
    p <- gerar_pins_programa()
    expect_length(p, 3)
    expect_false(anyDuplicated(p) > 0)
  }
})

test_that("o hash é salgado e confere o PIN certo", {
  h1 <- hash_senha("0427")
  h2 <- hash_senha("0427")

  expect_true(parece_hash(h1))
  expect_false(identical(h1, "0427"))
  expect_false(identical(h1, h2))          # salgado: nunca o PIN em claro
  expect_true(verificar_senha("0427", h1))
  expect_true(verificar_senha("0427", h2))
  expect_false(verificar_senha("0428", h1))
  expect_false(verificar_senha("AAAA-AAAA", h1))
})

test_that("PIN com menos de 4 números é completado com zeros à esquerda", {
  # O Excel abre "0427" como 427: quem digitar 427 tem de entrar.
  expect_equal(normalizar_senha("427"), "0427")
  expect_equal(normalizar_senha("7"), "0007")
  expect_equal(normalizar_senha(" 04 27 "), "0427")
  expect_equal(normalizar_senha("04-27"), "0427")
  expect_equal(normalizar_senha("04270"), "04270")   # 5 números: não mexe

  h <- hash_senha("0427")
  for (v in c("0427", "427", " 427", "04 27", "0-4-2-7")) {
    expect_true(verificar_senha(v, h), info = v)
  }
  for (v in c("4270", "04270", "042", "42")) {
    expect_false(verificar_senha(v, h), info = v)
  }
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

  # Antes: as 15 senhas eram todas diferentes. Com PIN de 4 números, dois
  # programas podem ter o mesmo PIN (o login os separa); dentro de um
  # programa, os 3 são diferentes.
  expect_true(all(grepl("^[0-9]{4}$", saida$senha)))
  por_programa <- tapply(saida$senha, saida$login, function(p) length(unique(p)))
  expect_true(all(por_programa == 3))
})

test_that("cada PIN abre a sua credencial e nenhuma outra do mesmo programa", {
  # Antes: "nenhuma outra" de nenhum programa. Com PIN, outro programa pode
  # ter o mesmo PIN por acaso; quem separa é o login.
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  saida <- carregar_programas(con, programas_sinteticos(2))
  cred <- DBI::dbGetQuery(con,
    "select p.login, c.ordem, c.senha_hash
       from credenciais c join programas p on p.id = c.programa_id")

  for (i in seq_len(nrow(saida))) {
    mesmo <- cred$login == saida$login[i]
    alvo  <- mesmo & cred$ordem == saida$ordem[i]
    expect_true(verificar_senha(saida$senha[i], cred$senha_hash[alvo]))
    for (h in cred$senha_hash[mesmo & !alvo]) {
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

# ---- CSV de ativas e de reservas -----------------------------------------

test_that("separar_senhas põe as ativas num arquivo e as reservas no outro", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  saida <- carregar_programas(con, programas_sinteticos(4))

  s <- separar_senhas(saida)

  expect_equal(nrow(s$ativas), 4)
  expect_equal(nrow(s$reservas), 8)
  expect_true(all(s$ativas$ordem == 1))
  expect_true(all(s$reservas$ordem %in% 2:3))
  expect_setequal(s$ativas$login, unique(saida$login))

  # nenhuma credencial se perde nem se repete entre os dois arquivos
  # (comparando login + ordem + PIN: com 4 números, dois programas podem
  # ter o mesmo PIN)
  chave <- function(d) paste(d$login, d$ordem, d$senha)
  expect_setequal(c(chave(s$ativas), chave(s$reservas)), chave(saida))
  expect_length(intersect(chave(s$ativas), chave(s$reservas)), 0)
  expect_equal(nrow(s$ativas) + nrow(s$reservas), nrow(saida))

  # as ativas do arquivo são as ativas do banco
  ativas_banco <- DBI::dbGetQuery(con,
    "select p.login, c.ordem from credenciais c
       join programas p on p.id = c.programa_id where c.ativa")
  expect_equal(sort(paste(s$ativas$login, s$ativas$ordem)),
               sort(paste(ativas_banco$login, ativas_banco$ordem)))

  # colunas do arquivo, sem a marca interna de ativa
  for (x in s) {
    expect_equal(names(x), c("login", "nome_oficial", "tipo", "ordem", "senha"))
  }
})

test_that("exigir_escrita aceita pasta gravável e recusa caminho impossível", {
  d <- tempfile(); dir.create(d); on.exit(unlink(d, recursive = TRUE))

  expect_silent(exigir_escrita(file.path(d, c("a.csv", "b.csv"))))
  expect_error(exigir_escrita(c(file.path(d, "a.csv"),
                                file.path(d, "nao-existe", "b.csv"))),
               "Nada foi gerado")
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

  # Só as colunas de texto (evento, detalhe) podem guardar algo vindo de
  # fora: id e hora são gerados pelo banco e têm números que poderiam
  # coincidir com um PIN de 4 números por acaso.
  log <- DBI::dbGetQuery(con, "select evento, detalhe from log")
  texto <- paste(c(log$evento, log$detalhe), collapse = " ")
  for (s in normalizar_senha(saida$senha)) expect_false(grepl(s, texto, fixed = TRUE))
  expect_false(grepl("$", texto, fixed = TRUE))
})

test_that("carga recusa lista com login repetido e nao grava nada", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))

  p <- programas_sinteticos(3)
  p$login[3] <- p$login[1]

  expect_error(carregar_programas(con, p), "logins repetidos")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0)
})
