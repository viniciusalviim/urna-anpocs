# Papéis impressos com a credencial: um por programa, com nome, login,
# PIN e um QR code que abre a urna. Usado por dev/gerar_papeis.R, que roda
# só no computador do responsável (como a geração dos PINs).
#
# O QR code contém SÓ o endereço da urna, igual para todos. Login e PIN
# vão escritos no papel e são sempre digitados: nunca vão na URL.
#
# Depende de R/comprovante.R (texto_latin1, ajustar_pdf).

# https://..., sem espaço, sem ? e sem # (que poderiam carregar dados).
validar_endereco_urna <- function(endereco) {
  if (length(endereco) != 1L || is.na(endereco)) {
    stop("Endereco da urna ausente.", call. = FALSE)
  }
  e <- trimws(endereco)
  if (!grepl("^https://[^[:space:]?#]+$", e)) {
    stop("Endereco da urna invalido: use https://..., sem espacos, sem ? e sem #.",
         call. = FALSE)
  }
  e
}

# Correção de erro nível M: lê mesmo com o papel um pouco amassado.
qr_da_urna <- function(endereco) {
  qrcode::qr_code(validar_endereco_urna(endereco), ecl = "M")
}

# Arquivos do sistema de teste (TESTE_), da rodada antiga (RODADA_) e do dev
# (DEV_). Os do sistema final começam com PRODUCAO_.
e_arquivo_de_teste <- function(arquivo) {
  grepl("^(TESTE|RODADA|DEV)_", basename(arquivo))
}

# Lê o CSV dos PINs ATIVOS (um por programa). Recusa o de reservas.
# A coluna se chama "senha" e guarda o PIN; lida como texto, o zero da
# frente não se perde.
ler_senhas_ativas <- function(arquivo) {
  if (grepl("RESERVA", basename(arquivo), ignore.case = TRUE)) {
    stop("Este e o arquivo de reservas. Os papeis usam so o das ativas.", call. = FALSE)
  }
  d <- utils::read.csv(arquivo, colClasses = "character", fileEncoding = "UTF-8")

  faltam <- setdiff(c("login", "nome_oficial", "ordem", "senha"), names(d))
  if (length(faltam)) {
    stop("Faltam colunas no arquivo: ", paste(faltam, collapse = ", "), call. = FALSE)
  }
  if (nrow(d) == 0L) stop("O arquivo esta vazio.", call. = FALSE)
  if (any(d$ordem != "1")) {
    stop("Ha senhas de ordem diferente de 1 (reservas) no arquivo. ",
         "Os papeis usam so as ativas.", call. = FALSE)
  }
  rep <- unique(d$login[duplicated(d$login)])
  if (length(rep)) stop("Login repetido: ", paste(rep, collapse = ", "), call. = FALSE)
  d
}

# Lê o logo da ANPOCS: <base>.png ou <base>.jpg (ou .jpeg). Sem ele, para:
# nenhum papel sai sem logo.
ler_logo <- function(base = "dev/logo_anpocs") {
  candidatos <- paste0(base, c(".png", ".jpg", ".jpeg"))
  arq <- candidatos[file.exists(candidatos)][1]
  if (is.na(arq)) {
    stop("Logo da ANPOCS não encontrado: coloque o arquivo em ", base, ".png ou ",
         base, ".jpg. Nenhum papel foi gerado.", call. = FALSE)
  }
  if (tolower(tools::file_ext(arq)) == "png") png::readPNG(arq) else jpeg::readJPEG(arq)
}

# Um papel (página A4) por linha de `senhas`, só com, de cima para baixo:
# o logo (canto superior esquerdo), "Assembleia ANPOCS", o nome oficial, o
# login, a senha (o PIN) em letra grande e o QR code com o endereço da urna.
# No sistema de teste, também o aviso "CREDENCIAL DE TESTE / este PIN NÃO
# vale na eleição".
#
# `logo`: a imagem lida por ler_logo(). `compactar = FALSE` só nos testes,
# para o texto do PDF ficar legível (com o logo em 119 páginas, o PDF sem
# compressão passaria de 60 MB).
gerar_papeis_pdf <- function(senhas, endereco, arquivo, teste = FALSE, logo,
                             compactar = TRUE) {
  endereco <- validar_endereco_urna(endereco)     # antes de abrir o arquivo
  if (missing(logo) || is.null(logo) || length(dim(logo)) < 2) {
    stop("Sem o logo da ANPOCS: nenhum papel foi gerado.", call. = FALSE)
  }
  qr <- qr_da_urna(endereco)
  L  <- texto_latin1
  raster_qr <- grDevices::as.raster(ifelse(qr, "black", "white"))

  larg <- 8.27; alt <- 11.69                      # A4, em polegadas
  # Um quadrado de `lado` polegadas, em unidades da página (0 a 1).
  em_x <- function(pol) pol / larg
  em_y <- function(pol) pol / alt

  grDevices::pdf(arquivo, width = larg, height = alt, encoding = "WinAnsi.enc",
                 compress = compactar, useKerning = FALSE,
                 title = "Credenciais de votacao")
  dispositivo <- grDevices::dev.cur()
  fechado <- FALSE
  on.exit(if (!fechado) grDevices::dev.off(dispositivo), add = TRUE)

  texto <- function(y, txt, cex = 1, font = 1, familia = "Helvetica", col = "black") {
    graphics::par(family = familia)
    graphics::text(0.5, y, txt, adj = c(0.5, 0.5), cex = cex, font = font, col = col)
  }

  for (i in seq_len(nrow(senhas))) {
    graphics::par(mar = c(0, 0, 0, 0), family = "Helvetica")
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")

    # Logo no canto superior esquerdo, 1,8 polegada de largura, sem deformar.
    lw <- 1.8
    lh <- lw * dim(logo)[1] / dim(logo)[2]
    topo <- 0.965
    graphics::rasterImage(logo, 0.06, topo - em_y(lh), 0.06 + em_x(lw), topo)

    # "Assembleia ANPOCS", centralizado, à altura do logo.
    texto(topo - em_y(lh) / 2, "Assembleia ANPOCS", cex = 1.8, font = 2)
    y <- topo - em_y(lh) - 0.035

    if (teste) {
      # O mesmo login terá outro PIN no sistema final: o aviso fica em
      # destaque para ninguém guardar este papel para o dia da eleição.
      graphics::rect(0.06, y - 0.07, 0.94, y, col = "#c62828", border = NA)
      texto(y - 0.022, "CREDENCIAL DE TESTE", cex = 1.4, font = 2, col = "white")
      texto(y - 0.052, L("este PIN NÃO vale na eleição"), cex = 1.25, font = 2, col = "white")
      y <- y - 0.11
    } else {
      y <- y - 0.03
    }

    # Nome oficial do programa ou centro.
    for (parte in strwrap(L(senhas$nome_oficial[i]), width = 52)) {
      texto(y, parte, cex = 1.5, font = 2)
      y <- y - 0.032
    }
    y <- y - 0.04

    texto(y, "Login", cex = 1.1); y <- y - 0.045
    texto(y, senhas$login[i], cex = 2.6, font = 2, familia = "Courier"); y <- y - 0.075
    texto(y, "Senha (PIN)", cex = 1.1); y <- y - 0.065
    texto(y, senhas$senha[i], cex = 5, font = 2, familia = "Courier"); y <- y - 0.075

    # QR code quadrado, centralizado, com o endereço da urna.
    lado <- 3.2
    graphics::rasterImage(raster_qr, 0.5 - em_x(lado) / 2, y - em_y(lado),
                          0.5 + em_x(lado) / 2, y, interpolate = FALSE)
  }

  grDevices::dev.off(dispositivo)
  fechado <- TRUE
  ajustar_pdf(arquivo, Sys.time())   # hífen de verdade (e não sinal de menos)
  invisible(arquivo)
}
