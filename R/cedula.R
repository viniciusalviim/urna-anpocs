# Urna ANPOCS 2026 — cédula
#
# Lê as chapas e descreve a opção digitada pelo votante. Não grava nada:
# o voto só existe em registrar_voto() (R/voto.R).

library(DBI)

# O que o botão ABSTENÇÃO escreve no campo da cédula. O valor gravado em
# votos.opcao é sempre "abstencao", sem acento.
TEXTO_ABSTENCAO <- "abstenção"   # abstenção

# Tira acento e caixa: "ABSTENÇÃO", "abstencao" e "Abstenção" viram
# "abstencao". Só cobre as letras acentuadas da palavra abstenção.
normalizar_opcao <- function(t) {
  tolower(chartr("çãÇÃ", "caCA", t))
}

# Lê o conteúdo da cédula: se aceita abstenção e as chapas com seus membros.
#
# Devolve list(permite_abstencao, chapas), onde chapas é uma lista nomeada
# pelo número da chapa ("1", "2", ...), cada uma com nome e membros
# (data.frame com nome, cargo e instituição, na ordem do cadastro; a
# instituição é NA se a chapa não a tiver).
ler_cedula <- function(con) {
  urna <- DBI::dbGetQuery(con, "select permite_abstencao from urna where id = 1")
  permite_abstencao <- nrow(urna) == 1L && isTRUE(urna$permite_abstencao)

  ch <- DBI::dbGetQuery(con,
    "select numero::text as numero, nome, membros::text as membros
       from chapas order by numero")

  chapas <- lapply(seq_len(nrow(ch)), function(i) {
    m <- jsonlite::fromJSON(ch$membros[i], simplifyDataFrame = TRUE)
    inst <- if (is.null(m$instituicao)) rep(NA_character_, length(m$nome)) else m$instituicao
    list(nome = ch$nome[i],
         membros = data.frame(nome = m$nome, cargo = m$cargo, instituicao = inst,
                              stringsAsFactors = FALSE))
  })
  names(chapas) <- ch$numero

  list(permite_abstencao = permite_abstencao, chapas = chapas)
}

# "Nome (Instituição)", ou só o nome, se não houver instituição.
rotulo_membro <- function(nome, instituicao) {
  sem <- is.na(instituicao) | !nzchar(trimws(instituicao))
  ifelse(sem, nome, paste0(nome, " (", instituicao, ")"))
}

# Membros agrupados pelo cargo, na ordem em que os cargos aparecem na chapa.
# Devolve uma lista de list(cargo, pessoas), com pessoas já como
# "Nome (Instituição)".
agrupar_membros <- function(membros) {
  if (is.null(membros) || nrow(membros) == 0L) return(list())
  inst <- if (is.null(membros$instituicao)) NA_character_ else membros$instituicao
  rotulos <- rotulo_membro(membros$nome, inst)
  lapply(unique(membros$cargo), function(cg) {
    list(cargo = cg, pessoas = rotulos[membros$cargo == cg])
  })
}

# Texto do botão CONFIRMA, a partir da opção que ele envia a registrar_voto().
rotulo_confirma <- function(opcao) {
  if (identical(opcao, "abstencao")) "CONFIRMAR ABSTENÇÃO"
  else paste("CONFIRMAR VOTO NA CHAPA", opcao)
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

  if (normalizar_opcao(t) == "abstencao") {
    if (!isTRUE(cedula$permite_abstencao)) return(inexistente)
    return(list(estado = "valida", opcao = "abstencao",
                nome = "Abstenção", membros = NULL))
  }

  # Só dígitos, e poucos: evita estouro de inteiro com texto longo.
  if (!grepl("^[0-9]{1,6}$", t)) return(inexistente)
  numero <- as.character(as.integer(t))   # "01" -> "1"

  chapa <- cedula$chapas[[numero]]
  if (is.null(chapa)) return(inexistente)

  list(estado = "valida", opcao = numero,
       nome = chapa$nome, membros = chapa$membros)
}
