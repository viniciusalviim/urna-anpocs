# Urna ANPOCS 2026 — abrir e encerrar a urna
#
# Usadas pelos scripts da rodada de teste e, depois, pelo painel do mesário.
# Estados: fechada -> aberta -> encerrada. Não há volta.
#
# Encerrar NÃO embaralha a tabela de votos: isso é o fechamento da etapa 7
# (seção 6 do CLAUDE.md).

library(DBI)

# Muda o estado da urna numa transação. `de` é o único estado de onde a
# mudança pode partir.
mudar_estado_urna <- function(con, de, para, coluna_hora, evento, detalhe = NULL) {
  recusar <- function(motivo) {
    stop(structure(class = c("urna_recusa", "error", "condition"),
                   list(message = motivo, call = NULL)))
  }

  DBI::dbBegin(con)

  tryCatch({
    # FOR UPDATE espera terminar qualquer voto em curso (que trava a linha da
    # urna com FOR SHARE). Nenhum voto fica pela metade no encerramento.
    u <- DBI::dbGetQuery(con, "select estado from urna where id = 1 for update")
    if (nrow(u) != 1L)            recusar("urna_nao_configurada")
    if (u$estado != de) {
      recusar(switch(u$estado,
                     fechada   = "nao_aberta",
                     aberta    = "ja_aberta",
                     encerrada = "ja_encerrada"))
    }

    DBI::dbExecute(con, sprintf(
      "update urna set estado = $1, %s = now() where id = 1", coluna_hora),
      list(para))

    extra <- if (is.null(detalhe)) list() else detalhe(con)
    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ($1, $2)",
      list(evento, if (is.null(extra$texto)) NA_character_ else extra$texto))

    DBI::dbCommit(con)
    r <- list(ok = TRUE, estado = para)
    if (!is.null(extra$integridade)) r$integridade <- extra$integridade
    r
  },

  urna_recusa = function(e) {
    DBI::dbRollback(con)
    list(ok = FALSE, motivo = conditionMessage(e))
  },

  error = function(e) {
    DBI::dbRollback(con)
    list(ok = FALSE, motivo = "erro_interno", detalhe = conditionMessage(e))
  })
}

# fechada -> aberta
abrir_urna <- function(con) {
  mudar_estado_urna(con, de = "fechada", para = "aberta",
                    coluna_hora = "aberta_em", evento = "urna_aberta")
}

# aberta -> encerrada. Confere a integridade no mesmo instante e registra no
# log. Encerra mesmo se a integridade falhar: o resultado vai no log e na
# resposta, para a mesa tratar como incidente.
encerrar_urna <- function(con) {
  mudar_estado_urna(con, de = "aberta", para = "encerrada",
                    coluna_hora = "encerrada_em", evento = "urna_encerrada",
                    detalhe = function(con) {
                      i <- conferir_integridade(con)
                      list(integridade = i,
                           texto = sprintf("votantes=%d votos=%d integridade=%s",
                                           as.integer(i$votantes), as.integer(i$votos),
                                           if (isTRUE(i$ok)) "ok" else "DIVERGENTE"))
                    })
}

# Recusas de abrir_urna() e encerrar_urna(), em português.
MOTIVOS_URNA <- c(
  urna_nao_configurada = "A urna não está configurada neste banco.",
  ja_aberta            = "A urna já está aberta.",
  ja_encerrada         = "A urna já foi encerrada. Ela não reabre.",
  nao_aberta           = "A urna não está aberta.",
  erro_interno         = "Erro ao falar com o banco. Nada mudou; tente de novo."
)

explicar_motivo_urna <- function(motivo) {
  m <- MOTIVOS_URNA[motivo]
  if (is.na(m)) paste("Recusado:", motivo) else unname(m)
}

# Resumo da urna para os scripts e o painel. Só contagens: nunca o conteúdo
# de um voto.
situacao_urna <- function(con) {
  u <- DBI::dbGetQuery(con,
    "select estado, modo, permite_abstencao, aberta_em, encerrada_em
       from urna where id = 1")
  i <- conferir_integridade(con)
  if (nrow(u) != 1L) {
    return(list(estado = NA_character_, modo = NA_character_,
                votantes = i$votantes, integridade_ok = i$ok))
  }
  list(
    estado            = u$estado,
    modo              = u$modo,
    permite_abstencao = u$permite_abstencao,
    aberta_em         = u$aberta_em,
    encerrada_em      = u$encerrada_em,
    votantes          = i$votantes,
    integridade_ok    = i$ok
  )
}

imprimir_situacao <- function(s) {
  hora <- function(t) if (is.null(t) || is.na(t)) "-" else format(t, "%d/%m/%Y %H:%M:%S")
  cat("  Estado da urna : ", s$estado, "\n",
      "  Modo           : ", s$modo, "\n",
      "  Aberta em      : ", hora(s$aberta_em), "\n",
      "  Encerrada em   : ", hora(s$encerrada_em), "\n",
      "  Votantes       : ", s$votantes, "\n",
      "  Integridade    : ", if (isTRUE(s$integridade_ok)) "ok (votantes = votos)"
                             else "DIVERGENTE - INCIDENTE", "\n", sep = "")
}
