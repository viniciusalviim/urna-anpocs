# Urna ANPOCS 2026 — login do votante
#
# Depende de R/credenciais.R (verificar_senha).

library(DBI)

normalizar_login <- function(login) tolower(trimws(login))

registrar_log <- function(con, evento, detalhe = NA_character_) {
  DBI::dbExecute(con,
    "insert into log (evento, detalhe) values ($1, $2)",
    list(evento, detalhe))
}

# Autentica um votante.
#
# Devolve list(ok = TRUE, programa_id, credencial_id, nome_oficial) ou
# list(ok = FALSE, motivo) com motivo em:
# urna_nao_aberta, credenciais_invalidas, programa_inapto, ja_votou.
#
# Regras:
# - Login inexistente e senha errada dao a MESMA resposta. Ninguem descobre
#   quais logins existem testando.
# - "ja_votou" so aparece DEPOIS da senha certa. Ninguem descobre quem ja
#   votou digitando logins.
# - Confere as credenciais na ordem e para na primeira que bate: quem usa a
#   credencial 1 paga uma conferencia lenta so, nao tres.
# - O log registra a tentativa, NUNCA o texto digitado.
#
# Esta funcao nao grava voto. A trava de verdade continua em registrar_voto().
autenticar <- function(con, login, senha) {
  force(login)
  force(senha)

  falha <- function(motivo) list(ok = FALSE, motivo = motivo)

  l <- normalizar_login(login)
  if (length(l) != 1L || is.na(l) || !nzchar(l)) {
    registrar_log(con, "login_falhou")
    return(falha("credenciais_invalidas"))
  }

  urna <- DBI::dbGetQuery(con, "select estado from urna where id = 1")
  if (nrow(urna) != 1L || urna$estado != "aberta") {
    return(falha("urna_nao_aberta"))
  }

  cred <- DBI::dbGetQuery(con,
    "select c.id, c.programa_id, c.senha_hash, p.nome_oficial, p.apto
       from credenciais c
       join programas p on p.id = c.programa_id
      where p.login = $1
      order by c.ordem",
    list(l))

  if (nrow(cred) == 0L) {
    registrar_log(con, "login_falhou")
    return(falha("credenciais_invalidas"))
  }

  achou <- NA_integer_
  for (i in seq_len(nrow(cred))) {
    if (verificar_senha(senha, cred$senha_hash[i])) {
      achou <- i
      break
    }
  }

  programa_id <- cred$programa_id[1]

  if (is.na(achou)) {
    registrar_log(con, "login_falhou", programa_id)
    return(falha("credenciais_invalidas"))
  }

  if (!isTRUE(cred$apto[achou])) {
    registrar_log(con, "login_recusado_inapto", programa_id)
    return(falha("programa_inapto"))
  }

  votou <- DBI::dbGetQuery(con,
    "select count(*)::int as n from votantes where programa_id = $1",
    list(programa_id))$n
  if (votou > 0L) {
    registrar_log(con, "login_recusado_ja_votou", programa_id)
    return(falha("ja_votou"))
  }

  registrar_log(con, "login_ok", programa_id)
  list(
    ok            = TRUE,
    programa_id   = programa_id,
    credencial_id = cred$id[achou],
    nome_oficial  = cred$nome_oficial[achou]
  )
}
