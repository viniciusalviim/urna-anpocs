# Ferramentas SO de desenvolvimento e da rodada de teste.
#
# Este arquivo fica em dev/ de proposito: o app nunca carrega nada daqui.
# Tudo o que apaga dados mora neste arquivo, e tudo passa por uma trava que
# le o carimbo gravado DENTRO do banco:
# - zerar_banco_dev() apaga TABELAS e so roda em 'dev' (exigir_banco_dev);
# - limpar_votos() apaga so votos, votantes e log, e so roda em 'teste'
#   (ou 'dev', nos testes automaticos). Nunca em 'producao'.

# Tabelas do sistema. A tabela 'ambiente' NAO esta aqui de proposito:
# o carimbo nunca e apagado.
TABELAS <- c("log", "votos", "votantes", "credenciais",
             "programas", "chapas", "urna")

exigir_banco_dev <- function(con) {
  if (is.na(ambiente_do_banco(con))) {
    stop("Este banco nao tem carimbo de ambiente.\n",
         "Rode dev/01_preparar_banco.R antes.", call. = FALSE)
  }
  exigir_ambiente(con, "dev")
  invisible(TRUE)
}

# Apaga todas as tabelas do sistema e recria vazias.
zerar_banco_dev <- function(con, caminho_schema) {
  exigir_banco_dev(con)
  DBI::dbExecute(con, paste("drop table if exists",
                            paste(TABELAS, collapse = ", "), "cascade"))
  executar_sql(con, caminho_schema)
  invisible(TRUE)
}

# Limpa os votos entre sessões da rodada de teste, mantendo as credenciais:
# as mesmas senhas valem em todas as sessões.
#
# Antes de apagar, grava em `pasta` três CSV com a data no nome: o log
# inteiro, a tabela votantes e a tabela votos (ordenada pelo id aleatório).
# Confere que os três foram gravados com o número certo de linhas. Depois,
# numa transação: apaga votos, votantes e log, e volta a urna para 'fechada'.
#
# Recusa urna aberta (encerre antes). Nunca roda em 'producao'.
limpar_votos <- function(con, pasta = "saida", ambientes = "teste",
                         quando = Sys.time()) {
  if ("producao" %in% ambientes) {
    stop("limpar_votos nunca roda em 'producao'. Nada foi apagado.", call. = FALSE)
  }
  exigir_ambiente(con, ambientes)

  base <- file.path(pasta, paste0("RODADA_arquivo_",
    format(quando, "%Y-%m-%d_%H%M%S", tz = "America/Sao_Paulo")))
  arquivos <- c(log      = paste0(base, "_log.csv"),
                votantes = paste0(base, "_votantes.csv"),
                votos    = paste0(base, "_votos.csv"))

  hora_texto <- function(df) {
    for (col in names(df)) {
      if (inherits(df[[col]], "POSIXct")) df[[col]] <- format(df[[col]], "%Y-%m-%d %H:%M:%S")
    }
    df
  }

  gravados <- FALSE
  criados  <- character()   # só estes podem ser removidos se algo falhar
  DBI::dbBegin(con)

  tryCatch({
    # Trava a urna: com ela assim, nenhum voto entra até o COMMIT.
    u <- DBI::dbGetQuery(con, "select estado from urna where id = 1 for update")
    if (nrow(u) != 1L)         stop("A urna nao esta configurada.", call. = FALSE)
    if (u$estado == "aberta")  stop("A urna esta aberta. Encerre antes de limpar.", call. = FALSE)

    if (any(file.exists(arquivos))) {
      stop("Ja existem arquivos com o nome ", basename(base), ".", call. = FALSE)
    }
    for (arq in arquivos) {
      pode <- tryCatch({ f <- file(arq, "w"); close(f); TRUE },
                       error = function(e) FALSE, warning = function(e) FALSE)
      if (!pode) stop("Nao consigo gravar em ", arq, ".", call. = FALSE)
      criados <- c(criados, arq)
    }

    # Log até aqui: o que entrar depois (tentativa de login) fica no banco.
    max_log <- DBI::dbGetQuery(con, "select coalesce(max(id), 0) as m from log")$m
    tabelas <- list(
      log      = DBI::dbGetQuery(con,
                   "select * from log where id <= $1 order by id", list(max_log)),
      votantes = DBI::dbGetQuery(con,
                   "select * from votantes order by votado_em, programa_id"),
      votos    = DBI::dbGetQuery(con,
                   "select id::text as id, opcao from votos order by id")
    )

    for (t in names(tabelas)) {
      utils::write.csv(hora_texto(tabelas[[t]]), arquivos[[t]],
                       row.names = FALSE, fileEncoding = "UTF-8")
      relido <- utils::read.csv(arquivos[[t]], colClasses = "character",
                                fileEncoding = "UTF-8")
      if (nrow(relido) != nrow(tabelas[[t]])) {
        stop("O arquivo ", arquivos[[t]], " nao confere com o banco.", call. = FALSE)
      }
    }
    gravados <- TRUE

    DBI::dbExecute(con, "delete from votos")
    DBI::dbExecute(con, "delete from votantes")
    DBI::dbExecute(con, "delete from log where id <= $1", list(max_log))
    DBI::dbExecute(con,
      "update urna set estado = 'fechada', aberta_em = null, encerrada_em = null
        where id = 1")

    n <- vapply(tabelas, nrow, integer(1))
    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('votos_limpos', $1)",
      list(sprintf("arquivado em %s: votantes=%d votos=%d log=%d",
                   basename(base), n[["votantes"]], n[["votos"]], n[["log"]])))

    DBI::dbCommit(con)
    list(ok = TRUE, arquivos = unname(arquivos),
         votantes = n[["votantes"]], votos = n[["votos"]], log = n[["log"]])
  },

  error = function(e) {
    DBI::dbRollback(con)
    if (!gravados) suppressWarnings(unlink(criados))
    stop(conditionMessage(e), " Nada foi apagado.", call. = FALSE)
  })
}

# n programas falsos. Um a cada 12 e Centro de Pesquisa, para o sistema ja
# nascer lidando com os dois tipos que o regimento preve.
programas_sinteticos <- function(n) {
  i <- seq_len(n)
  centro <- i %% 12 == 0
  data.frame(
    id           = sprintf("prog%03d", i),
    nome_oficial = ifelse(centro,
                          sprintf("Centro de Pesquisa de Teste %03d", i),
                          sprintf("Programa de Pos-Graduacao de Teste %03d", i)),
    tipo         = ifelse(centro, "centro", "ppg"),
    login        = sprintf("teste-%03d", i),
    stringsAsFactors = FALSE
  )
}
