# Urna ANPOCS 2026 — a chapa de cada sistema
#
# A eleição tem chapa única (número 1) e abstenção.
# - Sistema de TESTE: chapa de exemplo, com nomes inventados.
# - Sistema FINAL: a chapa real. Fica NULL até ser preenchida, e o script de
#   preparação se recusa a preparar produção sem ela.

CHAPA_TESTE <- list(
  numero  = 1L,
  nome    = "Chapa de Exemplo (sistema de teste)",
  membros = data.frame(
    nome  = c("Ana Fictícia", "Bruno Inventado", "Carla Imaginária", "Diego Suposto"),
    cargo = c("Presidência", "Secretaria Executiva", "Conselho Fiscal", "Conselho Fiscal"),
    stringsAsFactors = FALSE
  )
)

# Preencher antes de preparar o sistema final, no mesmo formato:
# list(numero = 1L, nome = "...",
#      membros = data.frame(nome = c(...), cargo = c(...)))
CHAPA_OFICIAL <- NULL

chapa_do_ambiente <- function(ambiente) {
  if (identical(ambiente, "producao")) {
    if (is.null(CHAPA_OFICIAL)) {
      stop("A chapa oficial ainda não foi preenchida em preparar/chapas.R. ",
           "Nada foi feito.", call. = FALSE)
    }
    return(CHAPA_OFICIAL)
  }
  CHAPA_TESTE
}

validar_chapa <- function(chapa) {
  n <- chapa$numero
  if (length(n) != 1L || is.na(n) || n != round(n) || n < 1 || n > 99) {
    stop("O número da chapa precisa ser um inteiro de 1 a 99.", call. = FALSE)
  }
  if (length(chapa$nome) != 1L || is.na(chapa$nome) || !nzchar(trimws(chapa$nome))) {
    stop("A chapa precisa de um nome.", call. = FALSE)
  }
  m <- chapa$membros
  if (!is.data.frame(m) || !all(c("nome", "cargo") %in% names(m)) || nrow(m) == 0L) {
    stop("A chapa precisa de pelo menos um membro, com nome e cargo.", call. = FALSE)
  }
  vazio <- function(x) is.na(x) | !nzchar(trimws(x))
  if (any(vazio(m$nome) | vazio(m$cargo))) {
    stop("Todo membro precisa de nome e cargo.", call. = FALSE)
  }
  invisible(TRUE)
}

# Grava a chapa. Os membros vão em jsonb, na ordem dada, como a cédula lê.
cadastrar_chapa <- function(con, chapa) {
  validar_chapa(chapa)
  membros <- as.character(jsonlite::toJSON(
    chapa$membros[, c("nome", "cargo")], dataframe = "rows"))
  invisible(DBI::dbExecute(con,
    "insert into chapas (numero, nome, membros) values ($1, $2, $3::jsonb)",
    list(as.integer(chapa$numero), trimws(chapa$nome), membros)))
}
