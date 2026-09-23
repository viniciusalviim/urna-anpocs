# Urna ANPOCS 2026 — cédula
#
# Lê as chapas e descreve a opção digitada pelo votante. Não grava nada:
# o voto só existe em registrar_voto() (R/voto.R).

library(DBI)

# Lê o conteúdo da cédula: se aceita branco e as chapas com seus membros.
#
# Devolve list(permite_branco, chapas), onde chapas é uma lista nomeada pelo
# número da chapa ("1", "2", ...), cada uma com nome e membros
# (data.frame com nome e cargo, na ordem do cadastro).
ler_cedula <- function(con) {
  urna <- DBI::dbGetQuery(con, "select permite_branco from urna where id = 1")
  permite_branco <- nrow(urna) == 1L && isTRUE(urna$permite_branco)

  ch <- DBI::dbGetQuery(con,
    "select numero::text as numero, nome, membros::text as membros
       from chapas order by numero")

  chapas <- lapply(seq_len(nrow(ch)), function(i) {
    m <- jsonlite::fromJSON(ch$membros[i], simplifyDataFrame = TRUE)
    list(nome = ch$nome[i],
         membros = data.frame(nome = m$nome, cargo = m$cargo))
  })
  names(chapas) <- ch$numero

  list(permite_branco = permite_branco, chapas = chapas)
}

# Descreve o que está digitado no campo da cédula.
#
# Devolve list(estado, opcao, nome, membros) com estado em:
# - "vazio"       nada digitado;
# - "valida"      opcao é o valor a entregar a registrar_voto();
# - "inexistente" não corresponde a nenhuma opção desta cédula.
# Fora de "valida", opcao é NULL.
descrever_opcao <- function(cedula, texto) {
  vazio       <- list(estado = "vazio")
  inexistente <- list(estado = "inexistente")

  if (length(texto) != 1L || is.na(texto)) return(vazio)
  t <- trimws(texto)
  if (!nzchar(t)) return(vazio)

  if (tolower(t) == "branco") {
    if (!isTRUE(cedula$permite_branco)) return(inexistente)
    return(list(estado = "valida", opcao = "branco",
                nome = "Voto em branco", membros = NULL))
  }

  # Só dígitos, e poucos: evita estouro de inteiro com texto longo.
  if (!grepl("^[0-9]{1,6}$", t)) return(inexistente)
  numero <- as.character(as.integer(t))   # "01" -> "1"

  chapa <- cedula$chapas[[numero]]
  if (is.null(chapa)) return(inexistente)

  list(estado = "valida", opcao = numero,
       nome = chapa$nome, membros = chapa$membros)
}
