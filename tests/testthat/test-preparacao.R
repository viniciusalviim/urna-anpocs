# Preparação do banco com a lista oficial (sistema de teste e, depois, o
# final): leitura e limpeza da lista, chapa, PINs e o script único.

# ---- limpeza da lista ------------------------------------------------------

# Quatro colunas, como na planilha: UF, universidade, nome, login.
bruta_exemplo <- function() {
  data.frame(
    a = c("SP", " SP", "MG\u00a0", "RJ", "CE"),
    b = c("USP", "USP ", "PUC", "FCRB\u00a0", "UFC"),
    c = c("Programa de  Pós-Graduação em Sociologia",
          "Programa de Pós-Graduação de Pós-Graduação em X ",
          "Programa de Pós-Graduação em Y",
          "Casa\u00a0de Exemplo",
          "Mestrado Profissional de Sociologia"),
    d = c("USP-PPGS", " USP-X", "PUC-Y\u00a0", "fcrb", "UFC-PROF"),
    stringsAsFactors = FALSE
  )
}

correcoes_exemplo <- function() {
  data.frame(
    login = c("usp-x", "puc-y"),
    campo = c("nome", "universidade"),
    de    = c("Programa de Pós-Graduação de Pós-Graduação em X", "PUC"),
    para  = c("Programa de Pós-Graduação em X", "PUC-MG"),
    stringsAsFactors = FALSE
  )
}

test_that("limpa espaços sobrando e espaço não separável; login em minúsculas", {
  l <- limpar_lista(bruta_exemplo(), correcoes_exemplo())
  tudo <- unlist(l)
  expect_false(any(grepl("\u00a0", tudo)))
  expect_false(any(grepl("  ", tudo)))
  expect_true(all(tudo == trimws(tudo)))
  expect_equal(l$login, c("usp-ppgs", "usp-x", "puc-y", "fcrb", "ufc-prof"))
  expect_equal(l$id, l$login)
  expect_equal(l$uf, c("SP", "SP", "MG", "RJ", "CE"))
})

test_that("nome oficial é '<nome> – <universidade>', depois das correções", {
  l <- limpar_lista(bruta_exemplo(), correcoes_exemplo())
  expect_equal(l$nome_oficial[1], "Programa de Pós-Graduação em Sociologia – USP")
  expect_equal(l$nome_oficial[2], "Programa de Pós-Graduação em X – USP")
  expect_equal(l$nome_oficial[3], "Programa de Pós-Graduação em Y – PUC-MG")
  expect_equal(l$nome_oficial[4], "Casa de Exemplo – FCRB")
})

test_that("tipo: Programa, Mestrado ou Doutorado no nome é ppg; o resto é centro", {
  l <- limpar_lista(bruta_exemplo(), correcoes_exemplo())
  expect_equal(l$tipo, c("ppg", "ppg", "ppg", "centro", "ppg"))
})

test_that("recusa correção que não encontra o texto esperado (a lista mudou)", {
  cor <- correcoes_exemplo()
  cor$de[2] <- "PUC-XX"
  expect_error(limpar_lista(bruta_exemplo(), cor), "Correção")
  cor <- correcoes_exemplo()
  cor$login[1] <- "nao-existe"
  expect_error(limpar_lista(bruta_exemplo(), cor), "Correção")
})

test_that("recusa nomes oficiais repetidos", {
  b <- bruta_exemplo()
  b$c[3] <- b$c[1]; b$b[3] <- "USP"        # mesmo nome e universidade da linha 1
  cor <- correcoes_exemplo()[1, ]
  expect_error(limpar_lista(b, cor), "Nomes oficiais repetidos")
})

test_that("recusa login repetido (mesmo em maiúsculas), célula vazia, login inválido e colunas erradas", {
  b <- bruta_exemplo(); b$d[2] <- " usp-ppgs"
  expect_error(limpar_lista(b, correcoes_exemplo()[2, ]), "repetido")

  b <- bruta_exemplo(); b$b[5] <- " \u00a0 "
  expect_error(limpar_lista(b, correcoes_exemplo()), "vazia")

  b <- bruta_exemplo(); b$d[5] <- "UFC PROF"
  expect_error(limpar_lista(b, correcoes_exemplo()), "Login")

  expect_error(limpar_lista(bruta_exemplo()[, 1:3], correcoes_exemplo()), "colunas")
})

# ---- a lista oficial de verdade (só onde o arquivo existe) -----------------

ARQUIVO_LISTA <- file.path("..", "..", "saida", "Lista_Assembleia_Final.xlsx")

test_that("lista oficial: 119 programas, correções aplicadas, sem repetição", {
  skip_if_not(file.exists(ARQUIVO_LISTA), "lista oficial ausente nesta máquina")
  l <- ler_lista_oficial(ARQUIVO_LISTA)

  expect_equal(nrow(l), 119)
  expect_false(anyDuplicated(l$login) > 0)
  expect_false(anyDuplicated(l$nome_oficial) > 0)
  expect_true(all(grepl("^[a-z0-9-]+$", l$login)))
  expect_false(any(grepl("\u00a0|  ", unlist(l))))

  of <- stats::setNames(l$nome_oficial, l$login)
  pg <- "Programa de Pós-Graduação"
  expect_equal(of[["usp-ppgs"]], paste(pg, "em Sociologia – USP"))
  expect_equal(of[["usp-iri"]], paste(pg, "em Relações Internacionais – USP"))
  expect_equal(of[["ufscar-ppgas"]], paste(pg, "em Antropologia Social – UFSCar"))
  expect_equal(of[["ufpa-naea"]], "Núcleo de Altos Estudos Amazônicos – UFPA")
  expect_match(of[["unesp-ar-ppgcs"]], "– UNESP-Araraquara$")
  expect_match(of[["puc-ppgcs"]], "– PUC-MG$")
  expect_match(of[["puc-iri"]], "– PUC-MG$")
  expect_match(of[["puc-rs-ppgscp"]], "– PUC-RS$")
  expect_match(of[["puc-sp-ppgcs"]], "– PUC-SP$")
  expect_false("PUC" %in% l$universidade)

  # a confirmar com a ANPOCS: fica como está na lista
  expect_true("ufgs-ppgs" %in% l$login)
  expect_match(of[["ufgs-ppgs"]], "– UFGD$")
})

test_that("lista oficial: os 15 centros conferidos pelo responsável", {
  skip_if_not(file.exists(ARQUIVO_LISTA), "lista oficial ausente nesta máquina")
  l <- ler_lista_oficial(ARQUIVO_LISTA)
  expect_setequal(l$login[l$tipo == "centro"], c(
    "ufba-crh", "ufpa-naea", "mpeg", "fundaj-ips", "fcrb", "fgv-cpdoc", "coc",
    "puc-rio-iri", "cebrap", "cedec", "fbsp", "ufabc-cecs", "unicamp-nepo",
    "unicamp-nep", "unicamp-pagu"))
})

# ---- chapa -----------------------------------------------------------------

test_that("a chapa de exemplo do sistema de teste é válida e única", {
  expect_silent(validar_chapa(CHAPA_TESTE))
  expect_equal(CHAPA_TESTE$numero, 1L)
  expect_true(nrow(CHAPA_TESTE$membros) >= 1)
  expect_identical(chapa_do_ambiente("teste"), CHAPA_TESTE)
})

test_that("produção não prepara sem a chapa oficial preenchida", {
  skip_if(!is.null(CHAPA_OFICIAL), "a chapa oficial já foi preenchida")
  expect_error(chapa_do_ambiente("producao"), "chapa oficial")
})

test_that("validar_chapa recusa chapa sem nome, sem membros ou com cargo vazio", {
  ch <- CHAPA_TESTE; ch$nome <- " "
  expect_error(validar_chapa(ch), "nome")
  ch <- CHAPA_TESTE; ch$membros <- ch$membros[0, ]
  expect_error(validar_chapa(ch), "membro")
  ch <- CHAPA_TESTE; ch$membros$cargo[1] <- ""
  expect_error(validar_chapa(ch), "cargo")
  ch <- CHAPA_TESTE; ch$numero <- 0L
  expect_error(validar_chapa(ch), "número")
})

test_that("cadastrar_chapa grava a chapa única com membros e cargos", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao) values (1, 'aberta', 'teste', true)")
  cadastrar_chapa(con, CHAPA_TESTE)

  ced <- ler_cedula(con)
  expect_equal(names(ced$chapas), "1")
  expect_equal(ced$chapas[["1"]]$nome, CHAPA_TESTE$nome)
  expect_equal(ced$chapas[["1"]]$membros$nome, CHAPA_TESTE$membros$nome)
  expect_equal(ced$chapas[["1"]]$membros$cargo, CHAPA_TESTE$membros$cargo)
  expect_equal(descrever_opcao(ced, "1")$estado, "valida")
  expect_equal(descrever_opcao(ced, "2")$estado, "inexistente")
  expect_equal(descrever_opcao(ced, TEXTO_ABSTENCAO)$opcao, "abstencao")
})

# ---- nomes dos arquivos de PINs --------------------------------------------

test_that("os CSV de PINs dizem de qual sistema são", {
  a <- arquivos_de_pins("teste", "saida")
  expect_equal(unname(a["ativas"]), "saida/TESTE_PINS_ATIVOS_enviar_aos_coordenadores.csv")
  expect_equal(unname(a["reservas"]), "saida/TESTE_PINS_RESERVAS_guardar_com_a_mesa.csv")
  p <- arquivos_de_pins("producao", "saida")
  expect_equal(unname(p["ativas"]), "saida/PRODUCAO_PINS_ATIVOS_enviar_aos_coordenadores.csv")
  expect_true(e_arquivo_de_teste(a["ativas"]))
  expect_false(e_arquivo_de_teste(p["ativas"]))
  expect_error(arquivos_de_pins("outro", "saida"))
})

# ---- preparar_banco() (no banco de dev) ------------------------------------

lista_pequena <- function() limpar_lista(bruta_exemplo(), correcoes_exemplo())

test_that("preparar_banco carrega a lista, a chapa e a urna fechada, e grava os PINs", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  arq <- arquivos_de_pins("dev", pasta)

  r <- preparar_banco(con, "dev", lista_pequena(), CHAPA_TESTE, arq)
  expect_equal(r$programas, 5L)

  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 5L)
  expect_equal(DBI::dbGetQuery(con,
    "select count(*)::int as n from credenciais where ativa")$n, 5L)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from chapas")$n, 1L)
  u <- DBI::dbGetQuery(con, "select estado, modo, permite_abstencao from urna")
  expect_equal(u$estado, "fechada")
  expect_equal(u$modo, "teste")
  expect_true(u$permite_abstencao)

  p <- DBI::dbGetQuery(con, "select id, login, nome_oficial, tipo from programas order by id")
  expect_true("fcrb" %in% p$id)
  expect_equal(p$tipo[p$id == "fcrb"], "centro")

  ativas <- read.csv(arq[["ativas"]], colClasses = "character", fileEncoding = "UTF-8")
  reservas <- read.csv(arq[["reservas"]], colClasses = "character", fileEncoding = "UTF-8")
  expect_equal(nrow(ativas), 5)
  expect_equal(nrow(reservas), 10)
  expect_true(all(grepl("^[0-9]{4}$", c(ativas$senha, reservas$senha))))   # zeros preservados
  expect_true(all(ativas$ordem == "1"))
  expect_equal(sort(ativas$login), sort(p$login))
})

test_that("preparar_banco se recusa a rodar duas vezes no mesmo banco", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  preparar_banco(con, "dev", lista_pequena(), CHAPA_TESTE, arquivos_de_pins("dev", pasta))

  pasta2 <- withr::local_tempdir()
  expect_error(preparar_banco(con, "dev", lista_pequena(), CHAPA_TESTE,
                              arquivos_de_pins("dev", pasta2)), "já foi preparado")
  expect_length(list.files(pasta2), 0)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 5L)
})

test_that("preparar_banco recusa banco com outro carimbo e não mexe em nada", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  expect_error(preparar_banco(con, "teste", lista_pequena(), CHAPA_TESTE,
                              arquivos_de_pins("teste", pasta)), "carimbado como 'dev'")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0L)
  expect_length(list.files(pasta), 0)
})
