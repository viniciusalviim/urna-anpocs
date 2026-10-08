# Urna ANPOCS 2026 — a chapa
#
# A eleição tem chapa única (número 1) e abstenção. A chapa oficial é usada
# nos DOIS sistemas, teste e final (decisão de 08/10), e também no dev.
#
# Cada membro tem nome, cargo e instituição. Na cédula, os membros aparecem
# agrupados pelo cargo, na ordem desta tabela, como "Nome (Instituição)".

CHAPA_OFICIAL <- list(
  numero  = 1L,
  nome    = "Chapa 1",
  membros = data.frame(
    cargo = c(
      "Presidência",
      "Secretaria Executiva",
      "Secretaria Executiva Adjunta",
      "Diretoria de Antropologia",
      "Diretoria de Ciência Política",
      "Diretoria de Sociologia",
      "Diretoria de Publicações",
      "Comitê Acadêmico", "Comitê Acadêmico", "Comitê Acadêmico",
      "Conselho Fiscal", "Conselho Fiscal", "Conselho Fiscal"),
    nome = c(
      "Angela Maria Alonso",
      "Marjorie Marona",
      "Igor José de Renó Machado",
      "Osmundo Santos de Araujo Pinho",
      "Marisa von Bülow",
      "Alex Niche Teixeira",
      "Flavia Mateus Rios",
      "Adalberto Moreira Cardoso", "Patrice Schuch", "Rachel Meneguello",
      "Manoel Leonardo Wanderley Duarte Santos", "Francisco Jatobá de Andrade",
      "Antonella Maria Imperatriz Tassinari"),
    instituicao = c(
      "USP", "UNIRIO", "UFSCar", "UFRB", "UnB", "UFRGS", "USP",
      "UERJ", "UFRGS", "UNICAMP",
      "UFMG", "UFPE", "UFSC"),
    stringsAsFactors = FALSE
  )
)

# A mesma chapa nos dois sistemas. (O argumento fica para que o script de
# preparação continue o mesmo se um dia os sistemas tiverem chapas
# diferentes.)
chapa_do_ambiente <- function(ambiente) {
  stopifnot(length(ambiente) == 1L, ambiente %in% c("dev", "teste", "producao"))
  CHAPA_OFICIAL
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
  if ("instituicao" %in% names(m) && any(vazio(m$instituicao))) {
    stop("Todo membro precisa da instituição.", call. = FALSE)
  }
  invisible(TRUE)
}

# Grava a chapa. Os membros vão em jsonb, na ordem dada, como a cédula lê.
cadastrar_chapa <- function(con, chapa) {
  validar_chapa(chapa)
  colunas <- intersect(c("nome", "cargo", "instituicao"), names(chapa$membros))
  membros <- as.character(jsonlite::toJSON(chapa$membros[, colunas], dataframe = "rows"))
  invisible(DBI::dbExecute(con,
    "insert into chapas (numero, nome, membros) values ($1, $2, $3::jsonb)",
    list(as.integer(chapa$numero), trimws(chapa$nome), membros)))
}
