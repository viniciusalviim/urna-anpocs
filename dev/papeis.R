# Papéis impressos com a credencial: um por programa, com nome, login,
# senha e um QR code que abre a urna. Usado por dev/gerar_papeis.R, que roda
# só no computador do responsável (como a geração das senhas).
#
# O QR code contém SÓ o endereço da urna, igual para todos. Login e senha
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

e_arquivo_de_teste <- function(arquivo) {
  grepl("^(RODADA|DEV)_", basename(arquivo))
}

# Lê o CSV das senhas ATIVAS (uma por programa). Recusa o de reservas.
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

# Um papel (página A4) por linha de `senhas`.
gerar_papeis_pdf <- function(senhas, endereco, arquivo, teste = FALSE) {
  endereco <- validar_endereco_urna(endereco)     # antes de abrir o arquivo
  qr <- qr_da_urna(endereco)
  L  <- texto_latin1
  raster_qr <- grDevices::as.raster(ifelse(qr, "black", "white"))

  larg <- 8.27; alt <- 11.69                      # A4, em polegadas
  grDevices::pdf(arquivo, width = larg, height = alt, encoding = "WinAnsi.enc",
                 compress = FALSE, useKerning = FALSE,
                 title = "Credenciais de votacao")
  dispositivo <- grDevices::dev.cur()
  fechado <- FALSE
  on.exit(if (!fechado) grDevices::dev.off(dispositivo), add = TRUE)

  for (i in seq_len(nrow(senhas))) {
    graphics::par(mar = c(0, 0, 0, 0), family = "Helvetica")
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")

    y <- 0.95
    if (teste) {
      graphics::rect(0.06, 0.93, 0.94, 0.975, col = "#c62828", border = NA)
      graphics::text(0.5, 0.9525, L("CREDENCIAL DE TESTE — sem validade na eleição"),
                     col = "white", font = 2, cex = 1.3)
      y <- 0.90
    }

    linha <- function(txt, cex = 1, font = 1, passo = 0.035, familia = "Helvetica") {
      graphics::par(family = familia)
      graphics::text(0.08, y, txt, adj = c(0, 0.5), cex = cex, font = font)
      y <<- y - passo
    }

    linha(L("Eleição ANPOCS 2026 — credencial de votação"),
          cex = 1.5, font = 2, passo = 0.03)
    linha(L("Conselho Diretivo e Conselho Fiscal – biênio 2027–2028"),
          cex = 1, passo = 0.055)

    linha("Programa", cex = 0.9, passo = 0.028)
    for (parte in strwrap(L(senhas$nome_oficial[i]), width = 60)) {
      linha(parte, cex = 1.2, font = 2, passo = 0.03)
    }
    y <- y - 0.02

    linha("Login", cex = 0.9, passo = 0.035)
    linha(senhas$login[i], cex = 2.2, font = 2, passo = 0.06, familia = "Courier")
    linha("Senha", cex = 0.9, passo = 0.04)
    linha(senhas$senha[i], cex = 3, font = 2, passo = 0.07, familia = "Courier")

    # QR code quadrado no papel: a altura, em unidades da página, é
    # proporcional à largura.
    lado_x <- 0.36
    lado_y <- lado_x * larg / alt
    topo <- y
    graphics::rasterImage(raster_qr, 0.08, topo - lado_y, 0.08 + lado_x, topo,
                          interpolate = FALSE)
    graphics::par(family = "Helvetica")
    xi <- 0.49
    graphics::text(xi, topo - 0.01, "Para votar pelo celular:", adj = c(0, 1),
                   cex = 1, font = 2)
    instrucoes <- c(
      L("1. Aponte a câmera para o código ao lado."),
      L("2. Digite o login e a senha acima,"),
      L("   exatamente como estão."),
      L("3. Escolha, confirme e guarde o comprovante."),
      "",
      L("Ou digite o endereço:"))
    for (k in seq_along(instrucoes)) {
      graphics::text(xi, topo - 0.045 - (k - 1) * 0.026, instrucoes[k],
                     adj = c(0, 1), cex = 0.9)
    }
    graphics::par(family = "Courier")
    graphics::text(xi, topo - 0.045 - length(instrucoes) * 0.026, endereco,
                   adj = c(0, 1), cex = 0.75, font = 2)

    y <- topo - lado_y - 0.05
    graphics::par(family = "Helvetica")
    linha(L("Este papel é pessoal e vale um voto do programa. Não o entregue a outra pessoa."),
          cex = 0.85, passo = 0.025)
    linha(L("A mesma credencial foi enviada por e-mail: use uma ou outra, o voto é um só."),
          cex = 0.85, passo = 0.025)
  }

  grDevices::dev.off(dispositivo)
  fechado <- TRUE
  ajustar_pdf(arquivo, Sys.time())   # hífen de verdade (e não sinal de menos)
  invisible(arquivo)
}
