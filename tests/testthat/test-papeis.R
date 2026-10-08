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
      senha = c("0427", "1234", "9999"),
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

test_that("lê o arquivo dos PINs ativos, sem perder o zero da frente", {
  s <- ler_senhas_ativas(csv_ativas())
  expect_equal(nrow(s), 3)
  expect_equal(s$senha[1], "0427")
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

test_that("arquivos do sistema de teste, da rodada e do dev são de teste", {
  expect_true(e_arquivo_de_teste("saida/TESTE_PINS_ATIVOS_enviar_aos_coordenadores.csv"))
  expect_true(e_arquivo_de_teste("saida/RODADA_senhas_ATIVAS_enviar_aos_participantes.csv"))
  expect_true(e_arquivo_de_teste("saida/DEV_senhas_ATIVAS_enviar_aos_coordenadores.csv"))
  expect_false(e_arquivo_de_teste("saida/PRODUCAO_PINS_ATIVOS_enviar_aos_coordenadores.csv"))
  expect_false(e_arquivo_de_teste("saida/senhas_ATIVAS_enviar_aos_coordenadores.csv"))
})

# ---- o PDF -----------------------------------------------------------------

# Um logo de mentira (imagem 10 x 20, cinza), para os testes não dependerem
# do arquivo do logo da ANPOCS.
LOGO_FALSO <- array(0.5, dim = c(10, 20, 3))

conta <- function(t, padrao) lengths(regmatches(t, gregexpr(padrao, t, fixed = TRUE)))

test_that("um papel (página) por programa, só com o que o layout pede", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  gerar_papeis_pdf(s, END, pdf, teste = FALSE, logo = LOGO_FALSO, compactar = FALSE)

  t <- texto_pdf(pdf)
  expect_equal(lengths(regmatches(t, gregexpr("/Type /Page[^s]", t))), 3)

  # de cima para baixo: logo, título, nome, login, senha (PIN), QR code
  expect_equal(conta(t, "(Assembleia ANPOCS)"), 3)
  for (i in 1:3) {
    expect_true(grepl(s$login[i], t, fixed = TRUE), info = s$login[i])
    expect_true(grepl(s$senha[i], t, fixed = TRUE), info = s$senha[i])
  }
  # travessão trocado por hífen (o nome quebra em duas linhas logo depois dele)
  expect_true(grepl("Ciências Sociais -", t, fixed = TRUE))
  expect_true(grepl("(UFRJ)", t, fixed = TRUE))
  expect_false(grepl("–", t, fixed = TRUE))
  expect_equal(conta(t, "(Login)"), 3)
  expect_equal(conta(t, "(Senha (PIN))"), 3)
  # duas imagens por página: o logo e o QR code
  expect_equal(conta(t, "/Subtype /Image"), 6)

  # o resto saiu: nada de endereço escrito, instruções ou rodapé
  expect_false(grepl(END, t, fixed = TRUE))
  expect_false(grepl("Para votar pelo celular", t, fixed = TRUE))
  expect_false(grepl("Este papel", t, fixed = TRUE))
  expect_false(grepl("credencial de vota", t, fixed = TRUE))
  expect_false(grepl("CREDENCIAL DE TESTE", t, fixed = TRUE))
  expect_false(grepl("NÃO vale na eleição", t, fixed = TRUE))
  # hífen de verdade: quem digitar o que vê não erra
  expect_true(grepl("/Differences [ 45/hyphen]", t, fixed = TRUE))
})

test_that("papéis de teste trazem o aviso de que o PIN não vale na eleição", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  gerar_papeis_pdf(s, END, pdf, teste = TRUE, logo = LOGO_FALSO, compactar = FALSE)
  t <- texto_pdf(pdf)
  expect_equal(conta(t, "CREDENCIAL DE TESTE"), 3)
  expect_equal(conta(t, "este PIN NÃO vale na eleição"), 3)
})

test_that("o PDF para imprimir sai compactado e com o hífen corrigido", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  gerar_papeis_pdf(s, END, pdf, teste = FALSE, logo = LOGO_FALSO)
  # comprimido, o PDF tem bytes nulos: a busca é direto nos bytes
  b <- readBin(pdf, "raw", file.size(pdf))
  expect_true(length(grepRaw("/FlateDecode", b, fixed = TRUE)) > 0)
  expect_true(length(grepRaw("/Differences [ 45/hyphen]", b, fixed = TRUE)) > 0)
  expect_length(grepRaw("/Differences [ 45/minus ]", b, fixed = TRUE), 0)
})

test_that("gerar_papeis_pdf recusa endereço inválido antes de escrever", {
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  expect_error(gerar_papeis_pdf(s, "http://x.org", pdf, logo = LOGO_FALSO))
  expect_false(file.exists(pdf))
})

# ---- o logo ----------------------------------------------------------------

test_that("ler_logo acha o logo em .png ou .jpg", {
  d <- withr::local_tempdir()
  img <- array(0.2, dim = c(4, 8, 3))

  jpeg::writeJPEG(img, file.path(d, "logo_anpocs.jpg"))
  expect_equal(dim(ler_logo(file.path(d, "logo_anpocs")))[1:2], c(4, 8))

  unlink(file.path(d, "logo_anpocs.jpg"))
  png::writePNG(img, file.path(d, "logo_anpocs.png"))
  expect_equal(dim(ler_logo(file.path(d, "logo_anpocs")))[1:2], c(4, 8))
})

test_that("sem o logo, para com mensagem clara em vez de gerar papel sem logo", {
  d <- withr::local_tempdir()
  expect_error(ler_logo(file.path(d, "logo_anpocs")), "Logo da ANPOCS não encontrado")
  s <- ler_senhas_ativas(csv_ativas())
  pdf <- tempfile(fileext = ".pdf")
  expect_error(gerar_papeis_pdf(s, END, pdf, logo = NULL), "logo")
  expect_false(file.exists(pdf))
})
