# Urna ANPOCS 2026 — credenciais
#
# Depende de R/voto.R (gerar_codigo, formatar_codigo): carregue voto.R antes.
#
# O banco NUNCA guarda a senha. Guarda so o hash: uma impressao digital que
# serve para conferir uma senha digitada, mas nao permite reconstrui-la.
# As senhas em texto existem uma unica vez, no data.frame devolvido por
# carregar_programas(), que vira o CSV entregue a secretaria.

library(DBI)
library(sodium)

# "K7PM-3XWQ": 8 caracteres do alfabeto sem ambiguos, em dois blocos de 4.
gerar_senha <- function() formatar_codigo(gerar_codigo(8))

# Tolerancia de digitacao: minusculas, hifen e espacos nao importam.
normalizar_senha <- function(senha) {
  toupper(gsub("[^A-Za-z0-9]", "", senha))
}

hash_senha <- function(senha) {
  sodium::password_store(normalizar_senha(senha))
}

verificar_senha <- function(senha, hash) {
  s <- normalizar_senha(senha)
  if (length(s) != 1L || is.na(s) || !nzchar(s)) return(FALSE)
  isTRUE(tryCatch(sodium::password_verify(hash, s), error = function(e) FALSE))
}

# Carrega os programas e cria 3 credenciais para cada um.
#
# 'programas' e um data.frame com as colunas: id, nome_oficial, tipo, login.
# Devolve um data.frame com as senhas EM TEXTO (login, nome_oficial, tipo,
# ordem, senha). Esse objeto e o unico lugar onde elas existem: grave em CSV
# e entregue. Nao ha como recupera-las depois.
#
# So roda em banco sem programas. Rodar de novo geraria senhas novas e o banco
# deixaria de bater com o CSV ja entregue.
carregar_programas <- function(con, programas) {
  colunas <- c("id", "nome_oficial", "tipo", "login")
  faltando <- setdiff(colunas, names(programas))
  if (length(faltando)) stop("Faltam colunas: ", paste(faltando, collapse = ", "))
  programas <- as.data.frame(programas)[, colunas]

  if (nrow(programas) == 0L)          stop("Nenhum programa para carregar.")
  if (anyDuplicated(programas$id))    stop("Ha ids repetidos na lista de programas.")
  if (anyDuplicated(programas$login)) stop("Ha logins repetidos na lista de programas.")

  recusar_se_ja_carregado <- function() {
    n <- DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n
    if (n > 0L) {
      stop("A tabela programas ja tem ", n, " linhas. A carga so roda em ",
           "banco vazio: gerar senhas de novo deixaria o banco diferente do ",
           "CSV entregue.", call. = FALSE)
    }
  }

  # Checagem rapida antes de gastar tempo gerando hashes...
  recusar_se_ja_carregado()

  cred <- data.frame(
    programa_id = rep(programas$id, each = 3L),
    ordem       = rep(1:3, times = nrow(programas)),
    stringsAsFactors = FALSE
  )
  cred$senha      <- vapply(seq_len(nrow(cred)), function(i) gerar_senha(), character(1))
  cred$senha_hash <- vapply(cred$senha, hash_senha, character(1), USE.NAMES = FALSE)

  DBI::dbBegin(con)
  tryCatch({
    # ...e de novo dentro da transacao, que e a que vale.
    recusar_se_ja_carregado()

    DBI::dbAppendTable(con, "programas", programas)
    DBI::dbAppendTable(con, "credenciais",
                       cred[, c("programa_id", "ordem", "senha_hash")])
    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('credenciais_geradas', $1)",
      list(sprintf("%d programas, %d credenciais", nrow(programas), nrow(cred))))

    DBI::dbCommit(con)
  }, error = function(e) {
    DBI::dbRollback(con)
    stop(conditionMessage(e), call. = FALSE)
  })

  i <- match(cred$programa_id, programas$id)
  data.frame(
    login        = programas$login[i],
    nome_oficial = programas$nome_oficial[i],
    tipo         = programas$tipo[i],
    ordem        = cred$ordem,
    senha        = cred$senha,
    stringsAsFactors = FALSE
  )
}
