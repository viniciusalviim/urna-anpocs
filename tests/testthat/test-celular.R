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

test_that("campo do PIN: rótulo PIN, teclado numérico no celular", {
  h <- html(campo_senha())
  expect_match(h, ">PIN</label>")
  expect_match(h, 'inputmode="numeric"')
  expect_match(h, 'pattern="[0-9]*"', fixed = TRUE)
  expect_match(codigo <- app_urna(), "Login ou PIN incorretos.", fixed = TRUE)
  expect_false(grepl("Login ou senha incorretos", codigo, fixed = TRUE))
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

# ---- a cédula com a chapa oficial ------------------------------------------

cedula_oficial <- function() {
  list(permite_abstencao = TRUE,
       chapas = list("1" = list(nome = CHAPA_OFICIAL$nome,
                                membros = CHAPA_OFICIAL$membros)))
}

test_that("membros agrupados pelo cargo, na ordem da chapa, como 'Nome (Instituição)'", {
  g <- agrupar_membros(CHAPA_OFICIAL$membros)
  expect_equal(length(g), 9)
  expect_equal(g[[1]]$cargo, "Presidência")
  expect_equal(g[[1]]$pessoas, "Angela Maria Alonso (USP)")
  expect_equal(g[[8]]$cargo, "Comitê Acadêmico")
  expect_equal(g[[8]]$pessoas, c("Adalberto Moreira Cardoso (UERJ)",
                                 "Patrice Schuch (UFRGS)",
                                 "Rachel Meneguello (UNICAMP)"))
  expect_equal(g[[9]]$cargo, "Conselho Fiscal")
  expect_equal(sum(lengths(lapply(g, `[[`, "pessoas"))), 13)

  expect_equal(rotulo_membro("Fulana", NA), "Fulana")
  expect_equal(rotulo_membro("Fulana", ""), "Fulana")
  expect_equal(rotulo_membro("Fulana", "USP"), "Fulana (USP)")
})

test_that("o cartão da chapa mostra os 13 nomes na ordem dos cargos", {
  h <- html(cartao_opcao(descrever_opcao(cedula_oficial(), "1")))
  expect_match(h, "Chapa 1")
  pos <- vapply(unique(CHAPA_OFICIAL$membros$cargo),
                function(cg) regexpr(cg, h, fixed = TRUE)[1], numeric(1))
  expect_true(all(pos > 0))
  expect_false(is.unsorted(pos))
  for (p in rotulo_membro(CHAPA_OFICIAL$membros$nome, CHAPA_OFICIAL$membros$instituicao)) {
    expect_match(h, p, fixed = TRUE)
  }
})

test_that("o CONFIRMA fica fixo na parte de baixo da tela, sempre à vista", {
  h <- html(cartao_opcao(descrever_opcao(cedula_oficial(), "1")))
  expect_match(h, 'class="urna-confirma"', fixed = TRUE)
  expect_match(h, 'id="confirma"', fixed = TRUE)
  expect_match(h, 'data-opcao="1"', fixed = TRUE)
  expect_match(h, "CONFIRMAR VOTO NA CHAPA 1", fixed = TRUE)
  # o botão vem dentro do bloco fixo
  expect_true(regexpr('class="urna-confirma"', h, fixed = TRUE) <
              regexpr('id="confirma"', h, fixed = TRUE))
  e <- html(estilo_celular())
  expect_match(e, ".urna-confirma", fixed = TRUE)
  expect_match(e, "position: sticky", fixed = TRUE)
  expect_match(e, "bottom: 0", fixed = TRUE)
})

test_that("o cartão da abstenção não tem membros e confirma a abstenção", {
  h <- html(cartao_opcao(descrever_opcao(cedula_oficial(), TEXTO_ABSTENCAO)))
  expect_match(h, "CONFIRMAR ABSTENÇÃO", fixed = TRUE)
  expect_match(h, 'data-opcao="abstencao"', fixed = TRUE)
  expect_false(grepl("Presidência", h, fixed = TRUE))
})

test_that("a urna usa os campos de celular", {
  codigo <- app_urna()
  expect_match(codigo, "campo_login()", fixed = TRUE)
  expect_match(codigo, "campo_senha()", fixed = TRUE)
  expect_match(codigo, "estilo_celular()", fixed = TRUE)
  expect_match(codigo, "aviso_comprovante_iphone()", fixed = TRUE)
  expect_match(codigo, "cartao_opcao(d)", fixed = TRUE)
})
