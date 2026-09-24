# Etapa 5 — comprovante.
#
# O PDF é gerado sem compressão: o texto fica legível dentro do arquivo, e
# os testes conferem o conteúdo sem precisar de pacote para ler PDF.

# Texto do PDF, em UTF-8, com os parênteses desescapados.
texto_do_pdf <- function(arquivo) {
  b <- readBin(arquivo, "raw", file.size(arquivo))
  s <- iconv(rawToChar(b), "latin1", "UTF-8")
  gsub("\\\\([()\\\\])", "\\1", s)
}

dados_exemplo <- function(nome = "Programa de Pós-Graduação em Ciências Sociais",
                          modo = "oficial") {
  list(
    nome_oficial   = nome,
    comprovante_id = "K7PM-3XWQ-ABCD",
    votado_em      = as.POSIXct("2026-10-09 19:42:07", tz = "America/Sao_Paulo"),
    modo           = modo
  )
}

pdf_de <- function(dados) {
  f <- tempfile(fileext = ".pdf")
  gerar_comprovante_pdf(dados, f)
  f
}

# ---- texto_latin1() ------------------------------------------------------

test_that("texto_latin1 preserva os acentos do português", {
  x <- "áàâãéêíóôõúüç ÁÀÂÃÉÊÍÓÔÕÚÜÇ"
  expect_equal(texto_latin1(x), x)
})

test_that("texto_latin1 troca travessão, aspas curvas e reticências", {
  expect_equal(texto_latin1("Ciências Sociais – UFRJ"),
               "Ciências Sociais - UFRJ")
  expect_equal(texto_latin1("biênio 2027–2028"), "biênio 2027-2028")
  expect_equal(texto_latin1("a—b"), "a-b")
  expect_equal(texto_latin1("“Nome” d’Oeste"), "\"Nome\" d'Oeste")
  expect_equal(texto_latin1("fim…"), "fim...")
  expect_equal(texto_latin1("a b"), "a b")
})

test_that("texto_latin1 junta acento separado da letra", {
  # "Pós-Graduação" com o acento como caractere à parte (forma decomposta)
  decomposto <- "Pós-Graduação"
  expect_equal(texto_latin1(decomposto), "Pós-Graduação")
})

test_that("texto_latin1 troca por '?' o que não cabe em Latin-1", {
  y <- texto_latin1("Programa 中 €")
  expect_equal(y, "Programa ? ?")
  expect_true(all(utf8ToInt(y) < 256))
})

# ---- dados_comprovante() -------------------------------------------------

test_that("dados_comprovante lê o que o banco gravou", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))

  r <- registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "1")
  d <- dados_comprovante(con, "prog01")

  v <- DBI::dbGetQuery(con,
    "select comprovante_id, votado_em from votantes where programa_id = 'prog01'")
  expect_equal(d$nome_oficial, "Programa de Teste 1")
  expect_equal(d$comprovante_id, r$comprovante_id)
  expect_equal(d$votado_em, v$votado_em)
  expect_equal(d$modo, "teste")
  expect_setequal(names(d), c("nome_oficial", "comprovante_id", "votado_em", "modo"))
})

test_that("dados_comprovante devolve NULL para programa que não votou", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  expect_null(dados_comprovante(con, "prog02"))
  expect_null(dados_comprovante(con, "nao-existe"))
})

# ---- gerar_comprovante_pdf() ---------------------------------------------

test_that("o PDF é um PDF", {
  f <- pdf_de(dados_exemplo())
  expect_gt(file.size(f), 500)
  expect_equal(rawToChar(readBin(f, "raw", 5)), "%PDF-")
})

test_that("o PDF traz programa, data e hora com segundos, identificador e a mensagem", {
  t <- texto_do_pdf(pdf_de(dados_exemplo()))

  expect_true(grepl("Programa de Pós-Graduação em Ciências Sociais", t, fixed = TRUE))
  expect_true(grepl("09/10/2026", t, fixed = TRUE))
  expect_true(grepl("19:42:07", t, fixed = TRUE))
  expect_true(grepl("horário de Brasília", t, fixed = TRUE))
  expect_true(grepl("K7PM-3XWQ-ABCD", t, fixed = TRUE))
  expect_true(grepl("VOTO DEPOSITADO", t, fixed = TRUE))
})

test_that("o hífen do identificador é hífen, não sinal de menos", {
  # Quem copiar o identificador do PDF tem de copiar "K7PM-3XWQ-ABCD".
  t <- texto_do_pdf(pdf_de(dados_exemplo()))
  expect_false(grepl("/minus", t, fixed = TRUE))
  expect_true(grepl("/Differences [ 45/hyphen]", t, fixed = TRUE))
  expect_true(grepl("K7PM-3XWQ-ABCD", t, fixed = TRUE))
})

test_that("a hora sai no horário de Brasília mesmo se vier em outro fuso", {
  d <- dados_exemplo()
  d$votado_em <- as.POSIXct("2026-10-09 22:42:07", tz = "UTC")   # = 19:42:07 BRT
  t <- texto_do_pdf(pdf_de(d))
  expect_true(grepl("19:42:07", t, fixed = TRUE))
  expect_false(grepl("22:42:07", t, fixed = TRUE))
})

test_that("nome com travessão e aspas curvas sai no PDF com equivalentes simples", {
  d <- dados_exemplo("Programa de Pós-Graduação em Ciências Sociais – UFRJ “Centro”")
  expect_silent(f <- pdf_de(d))
  t <- texto_do_pdf(f)
  expect_true(grepl("Ciências Sociais - UFRJ \"Centro\"", t, fixed = TRUE))
  expect_true(grepl("biênio 2027-2028", t, fixed = TRUE))
})

test_that("o PDF nunca traz o voto", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  registrar_voto(con, "prog01", credenciais_de(con, "prog01")[1], "2")

  # a função nem recebe a opção...
  expect_false("opcao" %in% names(formals(gerar_comprovante_pdf)))
  expect_false(any(grepl("opcao|voto", names(dados_comprovante(con, "prog01")))))

  # ...e o arquivo não cita chapa nem abstenção
  t <- texto_do_pdf(pdf_de(dados_comprovante(con, "prog01")))
  for (x in c("Chapa", "Dois", "absten", "Absten", "ABSTEN")) {
    expect_false(grepl(x, t, fixed = TRUE), info = x)
  }
})

test_that("mesmos dados geram o mesmo arquivo, byte a byte", {
  a <- pdf_de(dados_exemplo())
  Sys.sleep(1.1)   # só no teste: garante que o relógio mudou entre as duas
  b <- pdf_de(dados_exemplo())
  expect_identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b)))

  # a data interna do PDF é a do voto, não a da geração
  t <- texto_do_pdf(a)
  expect_true(grepl("/CreationDate (D:20261009194207)", t, fixed = TRUE))
  expect_true(grepl("/ModDate (D:20261009194207)", t, fixed = TRUE))
})

# ---- faixa de teste ------------------------------------------------------

test_that("em modo teste o comprovante traz a faixa; em modo oficial, não", {
  teste   <- texto_do_pdf(pdf_de(dados_exemplo(modo = "teste")))
  oficial <- texto_do_pdf(pdf_de(dados_exemplo(modo = "oficial")))

  expect_true(grepl("URNA DE TESTE - votos sem validade", teste, fixed = TRUE))
  expect_false(grepl("URNA DE TESTE", oficial, fixed = TRUE))
})

test_that("modo desconhecido é tratado como teste: a faixa aparece", {
  t <- texto_do_pdf(pdf_de(dados_exemplo(modo = NA_character_)))
  expect_true(grepl("URNA DE TESTE", t, fixed = TRUE))
})

test_that("ler_modo_urna lê o modo da urna", {
  con <- banco_limpo(); on.exit(DBI::dbDisconnect(con))
  expect_equal(ler_modo_urna(con), "teste")
  DBI::dbExecute(con, "update urna set modo = 'oficial'")
  expect_equal(ler_modo_urna(con), "oficial")
  DBI::dbExecute(con, "delete from urna")
  expect_true(is.na(ler_modo_urna(con)))
})
