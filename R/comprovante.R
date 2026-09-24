# Urna ANPOCS 2026 — comprovante de votação
#
# O comprovante prova PARTICIPAÇÃO, não conteúdo: nenhuma função daqui recebe
# ou lê a opção de voto. É isso que impede alguém de cobrar prova de voto de
# um coordenador.
#
# A urna (logo depois do voto) e o painel (reemissão) seguem o mesmo caminho:
# dados_comprovante() lê do banco, gerar_comprovante_pdf() monta o PDF só com
# esses dados. Mesmos dados, mesmo arquivo, byte a byte.
#
# O PDF sai do grDevices::pdf(), que vem com o R: sem LaTeX, sem navegador,
# sem pacote extra.

library(DBI)

FAIXA_TESTE <- "URNA DE TESTE — votos sem validade"

# Qualquer modo que não seja 'oficial' (inclusive urna sem configuração)
# mostra a faixa de teste. Na dúvida, a faixa aparece.
e_modo_teste <- function(modo) !identical(modo, "oficial")

# Devolve "teste", "oficial", ou NA se a urna não estiver configurada.
ler_modo_urna <- function(con) {
  m <- DBI::dbGetQuery(con, "select modo from urna where id = 1")$modo
  if (length(m) == 0L) NA_character_ else m
}

# Dados do comprovante de um programa, como o banco gravou.
#
# Devolve list(nome_oficial, comprovante_id, votado_em, modo), ou NULL se o
# programa não votou. votado_em é a hora gravada em votantes pelo banco, não
# a hora do app.
dados_comprovante <- function(con, programa_id) {
  r <- DBI::dbGetQuery(con,
    "select p.nome_oficial, v.comprovante_id, v.votado_em,
            (select modo from urna where id = 1) as modo
       from votantes v
       join programas p on p.id = v.programa_id
      where v.programa_id = $1",
    list(programa_id))
  if (nrow(r) != 1L) return(NULL)

  list(
    nome_oficial   = r$nome_oficial,
    comprovante_id = r$comprovante_id,
    votado_em      = r$votado_em,
    modo           = r$modo
  )
}

# ---- texto em Latin-1 ------------------------------------------------------
#
# A fonte padrão do PDF só tem os caracteres de Latin-1. Os acentos do
# português cabem; travessão, aspas curvas e reticências não.

# Letra + acento separado (forma decomposta) -> letra acentuada.
ACENTOS_SEPARADOS <- list(
  "́" = c(a = 0xe1, e = 0xe9, i = 0xed, o = 0xf3, u = 0xfa,
               A = 0xc1, E = 0xc9, I = 0xcd, O = 0xd3, U = 0xda),
  "̀" = c(a = 0xe0, A = 0xc0),
  "̂" = c(a = 0xe2, e = 0xea, o = 0xf4, A = 0xc2, E = 0xca, O = 0xd4),
  "̃" = c(a = 0xe3, o = 0xf5, n = 0xf1, A = 0xc3, O = 0xd5, N = 0xd1),
  "̧" = c(c = 0xe7, C = 0xc7),
  "̈" = c(u = 0xfc, U = 0xdc)
)

# Caracteres fora de Latin-1 (ou quase invisíveis) -> equivalente simples.
EQUIVALENTES <- c(
  "‐" = "-", "‑" = "-", "‒" = "-", "–" = "-",
  "—" = "-", "―" = "-", "−" = "-",
  "‘" = "'", "’" = "'", "‚" = "'", "‛" = "'", "′" = "'",
  "“" = "\"", "”" = "\"", "„" = "\"", "‟" = "\"", "″" = "\"",
  "…" = "...",
  " " = " ", " " = " ", " " = " ", " " = " ",
  " " = " ", "　" = " ",
  "​" = "", "‌" = "", "‍" = "", "﻿" = ""
)

# Deixa o texto só com caracteres de Latin-1, sem perder os acentos do
# português. O que não tiver equivalente vira "?".
texto_latin1 <- function(x) {
  x <- enc2utf8(as.character(x))

  for (acento in names(ACENTOS_SEPARADOS)) {
    tabela <- ACENTOS_SEPARADOS[[acento]]
    for (letra in names(tabela)) {
      x <- gsub(paste0(letra, acento), intToUtf8(tabela[[letra]]), x, fixed = TRUE)
    }
  }
  for (de in names(EQUIVALENTES)) {
    x <- gsub(de, EQUIVALENTES[[de]], x, fixed = TRUE)
  }

  vapply(x, function(s) {
    if (is.na(s)) return(NA_character_)
    cp <- utf8ToInt(s)
    cp <- cp[!(cp >= 0x300 & cp <= 0x36f)]         # acento solto que sobrou
    cp[cp < 32] <- 32                                # controle -> espaço
    cp[cp > 255 | (cp >= 127 & cp < 160)] <- 63      # fora de Latin-1 -> "?"
    intToUtf8(cp)
  }, character(1), USE.NAMES = FALSE)
}

# ---- o PDF -----------------------------------------------------------------

formatar_hora_brasilia <- function(t) {
  format(t, "%d/%m/%Y %H:%M:%S", tz = "America/Sao_Paulo")
}

# Gera o comprovante em PDF em `arquivo`, a partir SÓ de `dados`
# (a lista devolvida por dados_comprovante()).
gerar_comprovante_pdf <- function(dados, arquivo) {
  L <- function(s) texto_latin1(s)

  nome   <- strwrap(L(dados$nome_oficial), width = 70)
  quando <- formatar_hora_brasilia(dados$votado_em)

  # WinAnsi: nos acentos é igual a Latin-1, e texto_latin1() nunca produz os
  # caracteres em que as duas diferem. O hífen é tratado em ajustar_pdf().
  grDevices::pdf(arquivo, width = 8.27, height = 11.69,     # A4
                 encoding = "WinAnsi.enc", compress = FALSE,
                 useKerning = FALSE, title = "Comprovante de votacao")
  dispositivo <- grDevices::dev.cur()
  fechado <- FALSE
  on.exit(if (!fechado) grDevices::dev.off(dispositivo), add = TRUE)

  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")

  y <- 0.95
  if (e_modo_teste(dados$modo)) {
    graphics::rect(0.05, 0.915, 0.95, 0.975, col = "#c62828", border = NA)
    graphics::text(0.5, 0.945, L(FAIXA_TESTE), col = "white", font = 2, cex = 1.4)
    y <- 0.88
  }

  linha <- function(txt, cex = 1, font = 1, passo = 0.035) {
    graphics::text(0.08, y, txt, adj = c(0, 0.5), cex = cex, font = font)
    y <<- y - passo
  }

  linha(L("Eleição ANPOCS 2026"), cex = 1.6, font = 2, passo = 0.035)
  linha(L("Conselho Diretivo e Conselho Fiscal – biênio 2027–2028"),
        cex = 1.05, passo = 0.06)
  linha(L("COMPROVANTE DE VOTAÇÃO"), cex = 1.2, font = 2, passo = 0.07)
  linha("VOTO DEPOSITADO", cex = 2, font = 2, passo = 0.08)

  linha("Programa", cex = 0.9, passo = 0.03)
  for (i in seq_along(nome)) linha(nome[i], cex = 1.15, font = 2, passo = 0.03)
  y <- y - 0.02

  linha("Data e hora", cex = 0.9, passo = 0.03)
  linha(paste0(quando, L(" (horário de Brasília)")),
        cex = 1.15, font = 2, passo = 0.05)

  linha("Identificador do comprovante", cex = 0.9, passo = 0.03)
  linha(dados$comprovante_id, cex = 1.4, font = 2, passo = 0.08)

  linha(L("Este comprovante atesta a participação do programa na votação."),
        cex = 0.9, passo = 0.025)
  linha(L("Ele não contém o voto, e o voto não pode ser recuperado a partir dele."),
        cex = 0.9, passo = 0.025)

  grDevices::dev.off(dispositivo)
  fechado <- TRUE

  ajustar_pdf(arquivo, dados$votado_em)
  invisible(arquivo)
}

# Dois ajustes no arquivo pronto, sempre trocando texto por texto do MESMO
# tamanho (o índice interno do PDF conta bytes):
#
# 1. Data. O pdf() grava a hora em que o arquivo foi gerado (/CreationDate
#    e /ModDate). Trocamos pela hora do voto: mesmos dados => mesmo arquivo.
# 2. Hífen. O pdf() do R desenha o caractere "-" como sinal de menos
#    (/Differences [ 45/minus ]), e quem copiasse o identificador do PDF
#    copiaria outro caractere (U+2212). Trocamos por /hyphen.
ajustar_pdf <- function(arquivo, votado_em) {
  b <- readBin(arquivo, "raw", file.size(arquivo))
  s <- rawToChar(b)
  d <- format(votado_em, "D:%Y%m%d%H%M%S", tz = "America/Sao_Paulo")

  s <- gsub("(/(CreationDate|ModDate) \\()D:[0-9]{14}\\)",
            paste0("\\1", d, ")"), s, useBytes = TRUE)

  if (!grepl("/Differences [ 45/minus ]", s, fixed = TRUE, useBytes = TRUE)) {
    stop("ajustar_pdf: o PDF nao tem a codificacao esperada do hifen.")
  }
  s <- gsub("/Differences [ 45/minus ]", "/Differences [ 45/hyphen]", s,
            fixed = TRUE, useBytes = TRUE)

  if (nchar(s, type = "bytes") != length(b)) {
    stop("ajustar_pdf mudou o tamanho do PDF; o arquivo foi descartado.")
  }
  writeBin(charToRaw(s), arquivo)
  invisible(arquivo)
}
