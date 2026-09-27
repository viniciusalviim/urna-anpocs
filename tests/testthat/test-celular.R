# Urna no celular (votação híbrida: na sala, pelo próprio celular).

html <- function(x) as.character(htmltools::renderTags(x)$html)

app_urna <- function() {
  paste(readLines(file.path("..", "..", "urna", "app.R"), encoding = "UTF-8"),
        collapse = "\n")
}

test_that("a tela de login não recomenda mais o computador", {
  expect_false(grepl("Recomendamos votar pelo computador", app_urna(), fixed = TRUE))
})

test_that("login e senha nunca vêm da URL", {
  codigo <- app_urna()
  for (x in c("parseQueryString", "url_search", "clientData$url", "url_hash")) {
    expect_false(grepl(x, codigo, fixed = TRUE), info = x)
  }
})

test_that("campo de login: sem maiúscula automática, sem corretor, sem sugestão", {
  h <- html(campo_login())
  expect_match(h, 'id="login"')
  expect_match(h, 'type="text"')
  expect_match(h, 'autocapitalize="none"')
  expect_match(h, 'autocorrect="off"')
  expect_match(h, 'spellcheck="false"')
  expect_match(h, 'autocomplete="off"')
})

test_that("campo de senha: escondido, com botão de olho para mostrar", {
  h <- html(campo_senha())
  expect_match(h, 'id="senha"')
  expect_match(h, 'type="password"')
  expect_match(h, 'autocapitalize="none"')
  expect_match(h, 'autocorrect="off"')
  expect_match(h, 'autocomplete="off"')
  expect_match(h, 'id="mostrar_senha"')
  expect_match(h, 'aria-label="Mostrar senha"')
  expect_match(h, "urnaMostrarSenha")
})

test_that("o estilo evita o zoom automático do iPhone e aumenta a área de toque", {
  h <- html(estilo_celular())
  expect_match(h, "font-size: 16px")
  expect_match(h, "min-height: 48px")
  expect_match(h, "overflow-wrap: anywhere")
})

test_that("a tela de voto depositado explica como salvar o comprovante no iPhone", {
  h <- html(aviso_comprovante_iphone())
  expect_match(h, 'id="aviso_iphone"')
  expect_match(h, "Compartilhar")
  expect_match(h, "Salvar em Arquivos")
  expect_match(h, "iPhone|iPad")
})

test_that("a urna usa os campos de celular", {
  codigo <- app_urna()
  expect_match(codigo, "campo_login()", fixed = TRUE)
  expect_match(codigo, "campo_senha()", fixed = TRUE)
  expect_match(codigo, "estilo_celular()", fixed = TRUE)
  expect_match(codigo, "aviso_comprovante_iphone()", fixed = TRUE)
})
