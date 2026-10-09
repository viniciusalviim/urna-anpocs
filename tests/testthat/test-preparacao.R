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

test_that("corrige um login, com o mesmo cuidado das outras correções", {
  cor <- rbind(correcoes_exemplo(),
               data.frame(login = "ufc-prof", campo = "login",
                          de = "ufc-prof", para = "ufc-profsocio"))
  l <- limpar_lista(bruta_exemplo(), cor)
  expect_true("ufc-profsocio" %in% l$login)
  expect_false("ufc-prof" %in% l$login)
  expect_equal(l$id[l$login == "ufc-profsocio"], "ufc-profsocio")

  # o login esperado não está na lista: para
  cor$login[3] <- "ufc-outro"; cor$de[3] <- "ufc-outro"
  expect_error(limpar_lista(bruta_exemplo(), cor), "Correção")
})

test_that("planilha com o login antigo ufgs-ppgs é recusada", {
  # A planilha oficial já traz ufgd-ppgs (corrigida em 08/10). Uma cópia
  # antiga, com ufgs-ppgs, faz a preparação parar.
  b <- bruta_exemplo(); b$d[5] <- "UFGS-PPGS"
  expect_error(limpar_lista(b, correcoes_exemplo()), "ufgs-ppgs")
  b$d[5] <- "UFGD-PPGS"
  expect_true("ufgd-ppgs" %in% limpar_lista(b, correcoes_exemplo())$login)
  expect_equal(LOGINS_SUBSTITUIDOS$de, "ufgs-ppgs")
  expect_equal(LOGINS_SUBSTITUIDOS$para, "ufgd-ppgs")
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

  # confirmado pela ANPOCS (08/10): o login certo é ufgd-ppgs
  expect_true("ufgd-ppgs" %in% l$login)
  expect_false("ufgs-ppgs" %in% l$login)
  expect_equal(l$id[l$login == "ufgd-ppgs"], "ufgd-ppgs")
  expect_match(of[["ufgd-ppgs"]], "– UFGD$")
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

test_that("a chapa oficial: Chapa 1, 13 membros, na ordem dos cargos", {
  expect_silent(validar_chapa(CHAPA_OFICIAL))
  expect_equal(CHAPA_OFICIAL$numero, 1L)
  expect_equal(CHAPA_OFICIAL$nome, "Chapa 1")

  m <- CHAPA_OFICIAL$membros
  expect_equal(nrow(m), 13)
  expect_equal(unique(m$cargo), c(
    "Presidência", "Secretaria Executiva", "Secretaria Executiva Adjunta",
    "Diretoria de Antropologia", "Diretoria de Ciência Política",
    "Diretoria de Sociologia", "Diretoria de Publicações",
    "Comitê Acadêmico", "Conselho Fiscal"))
  expect_equal(rotulo_membro(m$nome, m$instituicao), c(
    "Angela Maria Alonso (USP)",
    "Marjorie Marona (UNIRIO)",
    "Igor José de Renó Machado (UFSCar)",
    "Osmundo Santos de Araujo Pinho (UFRB)",
    "Marisa von Bülow (UnB)",
    "Alex Niche Teixeira (UFRGS)",
    "Flavia Mateus Rios (USP)",
    "Adalberto Moreira Cardoso (UERJ)",
    "Patrice Schuch (UFRGS)",
    "Rachel Meneguello (UNICAMP)",
    "Manoel Leonardo Wanderley Duarte Santos (UFMG)",
    "Francisco Jatobá de Andrade (UFPE)",
    "Antonella Maria Imperatriz Tassinari (UFSC)"))
  expect_equal(sum(m$cargo == "Comitê Acadêmico"), 3)
  expect_equal(sum(m$cargo == "Conselho Fiscal"), 3)
})

test_that("os dois sistemas, teste e final, usam a chapa oficial", {
  expect_identical(chapa_do_ambiente("teste"), CHAPA_OFICIAL)
  expect_identical(chapa_do_ambiente("producao"), CHAPA_OFICIAL)
  expect_false(exists("CHAPA_TESTE"))   # a chapa de exemplo saiu
})

test_that("validar_chapa recusa chapa sem nome, sem membros, cargo ou instituição vazios", {
  ch <- CHAPA_OFICIAL; ch$nome <- " "
  expect_error(validar_chapa(ch), "nome")
  ch <- CHAPA_OFICIAL; ch$membros <- ch$membros[0, ]
  expect_error(validar_chapa(ch), "membro")
  ch <- CHAPA_OFICIAL; ch$membros$cargo[1] <- ""
  expect_error(validar_chapa(ch), "cargo")
  ch <- CHAPA_OFICIAL; ch$membros$instituicao[5] <- " "
  expect_error(validar_chapa(ch), "institui")
  ch <- CHAPA_OFICIAL; ch$numero <- 0L
  expect_error(validar_chapa(ch), "número")
})

test_that("cadastrar_chapa grava a chapa com membros, cargos e instituições", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao) values (1, 'aberta', 'teste', true)")
  cadastrar_chapa(con, CHAPA_OFICIAL)

  ced <- ler_cedula(con)
  expect_equal(names(ced$chapas), "1")
  expect_equal(ced$chapas[["1"]]$nome, "Chapa 1")
  m <- ced$chapas[["1"]]$membros
  expect_equal(m$nome, CHAPA_OFICIAL$membros$nome)
  expect_equal(m$cargo, CHAPA_OFICIAL$membros$cargo)
  expect_equal(m$instituicao, CHAPA_OFICIAL$membros$instituicao)
  expect_equal(descrever_opcao(ced, "1")$estado, "valida")
  expect_equal(nrow(descrever_opcao(ced, "1")$membros), 13)
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

test_that("os CSV das avulsas dizem que são avulsas e ficam com a mesa", {
  a <- arquivos_de_pins("teste", "saida")
  expect_equal(unname(a["avulsas_ativas"]),
               "saida/TESTE_PINS_AVULSAS_ATIVOS_guardar_com_a_mesa.csv")
  expect_equal(unname(a["avulsas_reservas"]),
               "saida/TESTE_PINS_AVULSAS_RESERVAS_guardar_com_a_mesa.csv")
  p <- arquivos_de_pins("producao", "saida")
  expect_equal(unname(p["avulsas_ativas"]),
               "saida/PRODUCAO_PINS_AVULSAS_ATIVOS_guardar_com_a_mesa.csv")
  expect_length(unique(a), 4)
})

# ---- credenciais avulsas ---------------------------------------------------

lista_pequena <- function() limpar_lista(bruta_exemplo(), correcoes_exemplo())

test_that("10 credenciais avulsas: credencial-01 a credencial-10", {
  v <- credenciais_avulsas()
  expect_equal(nrow(v), 10)
  expect_equal(v$login, sprintf("credencial-%02d", 1:10))
  expect_equal(v$id, v$login)
  expect_equal(v$nome_oficial, sprintf("Credencial avulsa %02d", 1:10))
  expect_true(all(v$tipo %in% c("ppg", "centro")))   # o esquema só aceita esses
})

test_that("os logins das avulsas não colidem com a lista oficial", {
  skip_if_not(file.exists(ARQUIVO_LISTA), "lista oficial ausente nesta máquina")
  l <- ler_lista_oficial(ARQUIVO_LISTA)
  expect_length(intersect(l$login, credenciais_avulsas()$login), 0)
  expect_length(intersect(l$nome_oficial, credenciais_avulsas()$nome_oficial), 0)
})

test_that("preparar_banco carrega as avulsas, votando normalmente, com PINs em arquivos separados", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  arq <- arquivos_de_pins("dev", pasta)

  r <- preparar_banco(con, "dev", lista_pequena(), CHAPA_OFICIAL, arq,
                      avulsas = credenciais_avulsas())
  expect_equal(r$programas, 15L)
  expect_equal(r$avulsas, 10L)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from credenciais")$n, 45L)
  expect_equal(DBI::dbGetQuery(con,
    "select count(*)::int as n from credenciais c join programas p on p.id = c.programa_id
      where p.login like 'credencial-%' and c.ativa and p.apto")$n, 10L)

  ler <- function(k) read.csv(arq[[k]], colClasses = "character", fileEncoding = "UTF-8")
  ativas <- ler("ativas"); reservas <- ler("reservas")
  av_ativas <- ler("avulsas_ativas"); av_reservas <- ler("avulsas_reservas")

  # a secretaria não recebe as avulsas
  expect_equal(nrow(ativas), 5)
  expect_equal(nrow(reservas), 10)
  expect_false(any(grepl("^credencial-", c(ativas$login, reservas$login))))
  # as avulsas ficam com a mesa, em arquivos próprios
  expect_equal(av_ativas$login, sprintf("credencial-%02d", 1:10))
  expect_true(all(av_ativas$ordem == "1"))
  expect_equal(nrow(av_reservas), 20)
  expect_true(all(av_reservas$ordem %in% c("2", "3")))
  # os papéis das avulsas leem o arquivo das ativas delas
  expect_equal(nrow(ler_senhas_ativas(arq[["avulsas_ativas"]])), 10)

  # aparecem no painel como as outras
  lp <- listar_programas(con)
  expect_true(all(sprintf("credencial-%02d", 1:10) %in% lp$login))
  expect_equal(lp$credencial_ativa[lp$login == "credencial-03"], 1L)

  # e votam normalmente
  DBI::dbExecute(con, "update urna set estado = 'aberta', aberta_em = now()")
  a <- autenticar(con, "credencial-03", av_ativas$senha[av_ativas$login == "credencial-03"])
  expect_true(a$ok)
  expect_equal(a$nome_oficial, "Credencial avulsa 03")
  expect_true(registrar_voto(con, a$programa_id, a$credencial_id, "1")$ok)
  expect_true(conferir_integridade(con)$ok)
})

test_that("preparar_banco recusa avulsa com login que já está na lista", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  v <- credenciais_avulsas()
  v$login[1] <- "usp-ppgs"; v$id[1] <- "usp-ppgs"
  expect_error(preparar_banco(con, "dev", lista_pequena(), CHAPA_OFICIAL,
                              arquivos_de_pins("dev", withr::local_tempdir()),
                              avulsas = v), "avulsa")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0L)
})

# ---- preparar_banco() (no banco de dev) ------------------------------------

test_that("preparar_banco carrega a lista, a chapa e a urna fechada, e grava os PINs", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  arq <- arquivos_de_pins("dev", pasta)

  r <- preparar_banco(con, "dev", lista_pequena(), CHAPA_OFICIAL, arq)
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
  preparar_banco(con, "dev", lista_pequena(), CHAPA_OFICIAL, arquivos_de_pins("dev", pasta))

  pasta2 <- withr::local_tempdir()
  expect_error(preparar_banco(con, "dev", lista_pequena(), CHAPA_OFICIAL,
                              arquivos_de_pins("dev", pasta2)), "já foi preparado")
  expect_length(list.files(pasta2), 0)
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 5L)
})

test_that("preparar_banco recusa banco com outro carimbo e não mexe em nada", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  pasta <- withr::local_tempdir()
  expect_error(preparar_banco(con, "teste", lista_pequena(), CHAPA_OFICIAL,
                              arquivos_de_pins("teste", pasta)), "carimbado como 'dev'")
  expect_equal(DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n, 0L)
  expect_length(list.files(pasta), 0)
})
