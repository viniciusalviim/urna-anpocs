# Papéis impressos com a credencial e o QR code da urna.

texto_pdf <- function(arquivo) {
  b <- readBin(arquivo, "raw", file.size(arquivo))
  s <- iconv(rawToChar(b), "latin1", "UTF-8")
  gsub("\\\\([()\\\\])", "\\1", s)
}

csv_ativas <- function(linhas = NULL, nome = "senhas_ATIVAS.csv") {
  if (is.null(linhas)) {
    linhas <- data.frame(
      login = c("teste-001", "teste-002", "teste-003"),
      nome_oficial = c("Programa de Pós-Graduação em Ciências Sociais – UFRJ",
                       "Programa Dois", "Centro de Pesquisa Três"),
      tipo = c("ppg", "ppg", "centro"),
      ordem = c(1, 1, 1),
      senha = c("K7PM-3XWQ", "ABCD-EFGH", "2345-6789"),
      stringsAsFactors = FALSE)
  }
  arq <- file.path(withr::local_tempdir(.local_envir = parent.frame()), nome)
  write.csv(linhas, arq, row.names = FALSE, fileEncoding = "UTF-8")
  arq
}

END <- "https://anpocs.exemplo.org/urna"

# ---- endereço e QR ---------------------------------------------------------

test_that("o endereço tem de ser https, sem ? nem #", {
  expect_equal(validar_endereco_urna(END), END)
  for (e in c("", "   ", "http://anpocs.exemplo.org/urna", "anpocs.exemplo.org",
              "https://x.org/urna?login=teste-001", "https://x.org/urna#senha",
              "https://x.org/ur na", NA)) {
    expect_error(validar_endereco_urna(e), info = e)
  }
})

test_that("o QR code contém só o endereço da urna", {
  expect_identical(qr_da_urna(END), qrcode::qr_code(END, ecl = "M"))
  expect_error(qr_da_urna("https://x.org/urna?senha=1"))
})

# ---- leitura do arquivo das ativas -----------------------------------------

test_that("lê o arquivo das senhas ativas", {
  s <- ler_senhas_ativas(csv_ativas())
  expect_equal(nrow(s), 3)
  expect_equal(s$senha[1], "K7PM-3XWQ")
  expect_type(s$ordem, "character")
})

test_that("recusa o arquivo de reservas, ou qualquer ordem diferente de 1", {
  expect_error(ler_senhas_ativas(csv_ativas(nome = "X_senhas_RESERVAS_guardar.csv")),
               "reservas")
  d <- data.frame(login = c("a", "b"), nome_oficial = c("A", "B"), tipo = "ppg",
                  ordem = c(1, 2), senha = c("AAAA-AAAA", "BBBB-BBBB"))
  expect_error(ler_senhas_ativas(csv_ativas(d)), "ordem")
})

test_that("recusa logins repetidos, arquivo vazio e colunas faltando", {
  d <- data.frame(login = c("a", "a"), nome_oficial = c("A", "B"), tipo = "ppg",
                  ordem = 1, senha = c("AAAA-AAAA", "BBBB-BBBB"))
  expect_error(ler_senhas_ativas(csv_ativas(d)), "repetido")
  d0 <- data.frame(login = character(), nome_oficial = character(), tipo = character(),
                   ordem = numeric(), senha = character())
  expect_error(ler_senhas_ativas(csv_ativas(d0)), "vazio")
  expect_error(ler_senhas_ativas(csv_ativas(data.frame(login = "a", senha = "x"))),
               "colunas")
})

test_that("arquivos da rodada e do dev são de teste", {
  expect_true(e_arquivo_de_teste("saida/RODADA_senhas_ATIVAS_enviar_aos_participantes.csv"))
  expect_true(e_arquivo_de_teste("saida/DEV_senhas_ATIVAS_enviar_aos_coordenadores.csv"))
  expect_false(e_arquivo_de_teste("saida/senhas_ATIVAS_enviar_aos_coordenadores.csv"))
})

# ---- o PDF -----------------------------------------------------------------

test_that("um papel (página) por programa, com nome, login, senha e endereço", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  gerar_papeis_pdf(s, END, pdf, teste = FALSE)

  t <- texto_pdf(pdf)
  expect_equal(lengths(regmatches(t, gregexpr("/Type /Page[^s]", t))), 3)
  for (i in 1:3) {
    expect_true(grepl(s$login[i], t, fixed = TRUE), info = s$login[i])
    expect_true(grepl(s$senha[i], t, fixed = TRUE), info = s$senha[i])
  }
  expect_true(grepl("Ciências Sociais - UFRJ", t, fixed = TRUE))  # travessão trocado
  expect_true(grepl(END, t, fixed = TRUE))
  expect_false(grepl("CREDENCIAL DE TESTE", t, fixed = TRUE))
  # hífen de verdade: quem digitar o que vê não erra
  expect_true(grepl("/Differences [ 45/hyphen]", t, fixed = TRUE))
})

test_that("papéis de teste trazem a faixa", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  gerar_papeis_pdf(s, END, pdf, teste = TRUE)
  expect_true(grepl("CREDENCIAL DE TESTE", texto_pdf(pdf), fixed = TRUE))
})

test_that("gerar_papeis_pdf recusa endereço inválido antes de escrever", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  expect_error(gerar_papeis_pdf(s, "http://x.org", pdf))
  expect_false(file.exists(pdf))
})
