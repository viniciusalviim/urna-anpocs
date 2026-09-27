# Publicação no Connect Cloud.
#
# O Connect Cloud instala os pacotes listados no manifest.json de cada app,
# gerado por rsconnect::writeManifest(). Esse comando só procura pacotes
# dentro da pasta do app, e não veria os usados em R/. Por isso cada app tem
# um dependencias.R com um library() para cada pacote de R/.

raiz <- file.path("..", "..")
BASE <- c("base", "grDevices", "graphics", "stats", "utils", "tools", "methods")

pacotes_citados <- function(arquivos) {
  texto <- unlist(lapply(arquivos, readLines, warn = FALSE, encoding = "UTF-8"))
  texto <- sub("#.*$", "", texto)                       # ignora comentários
  lib <- regmatches(texto, gregexpr("library\\(([A-Za-z0-9.]+)\\)", texto))
  lib <- sub("library\\((.*)\\)", "\\1", unlist(lib))
  ns  <- regmatches(texto, gregexpr("\\b([A-Za-z][A-Za-z0-9.]*)::", texto))
  ns  <- sub("::$", "", unlist(ns))
  # "numero::text" num SQL não é pacote: fica só o que é pacote instalado.
  ns  <- ns[vapply(ns, function(p) nzchar(system.file(package = p)), logical(1))]
  setdiff(unique(c(lib, ns)), BASE)
}

pacotes_de_R <- function() {
  pacotes_citados(list.files(file.path(raiz, "R"), "\\.R$", full.names = TRUE))
}

for (app in c("urna", "painel")) {

  test_that(paste(app, "- dependencias.R cita todos os pacotes usados em R/ e no app"), {
    dep <- file.path(raiz, app, "dependencias.R")
    expect_true(file.exists(dep))
    precisa <- union(pacotes_de_R(),
                     pacotes_citados(file.path(raiz, app, "app.R")))
    declarados <- pacotes_citados(dep)
    expect_setequal(setdiff(precisa, declarados), character())
  })

  test_that(paste(app, "- manifest.json existe e lista esses pacotes"), {
    arq <- file.path(raiz, app, "manifest.json")
    expect_true(file.exists(arq))
    m <- jsonlite::fromJSON(arq, simplifyVector = FALSE)
    expect_equal(m$metadata$appmode, "shiny")
    expect_equal(m$metadata$primary_rmd %||% m$metadata$entrypoint %||% "app.R", "app.R")
    faltando <- setdiff(pacotes_citados(file.path(raiz, app, "dependencias.R")),
                        names(m$packages))
    expect_setequal(faltando, character())
  })
}

test_that("o app acha as funções de R/ rodando da pasta dele ou da raiz", {
  # A linha fica no próprio app: ela roda antes de existir qualquer função.
  linha <- 'PASTA_R <- if (dir.exists("../R")) "../R" else "R"'
  for (app in c("urna", "painel")) {
    codigo <- readLines(file.path(raiz, app, "app.R"), encoding = "UTF-8")
    expect_true(linha %in% trimws(codigo), info = app)
  }
  eval_linha <- function() { eval(parse(text = linha)); PASTA_R }
  withr::with_dir(raiz, expect_equal(eval_linha(), "R"))
  withr::with_dir(file.path(raiz, "urna"), expect_equal(eval_linha(), "../R"))
})

test_that("o .gitignore protege senhas, segredos e PDFs gerados", {
  gi <- readLines(file.path(raiz, ".gitignore"))
  for (x in c(".Renviron", "*.csv", "credenciais*.json", "saida/", "*.pdf")) {
    expect_true(x %in% gi, info = x)
  }
})
