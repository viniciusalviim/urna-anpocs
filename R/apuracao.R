# Urna ANPOCS 2026 — embaralhamento e apuração
#
# As ÚNICAS funções do sistema que leem o conteúdo da tabela votos, e só com
# a urna encerrada (invariante 9, em qualquer modo). O teste em
# test-apuracao.R confere que nenhuma outra função cita a tabela votos.

library(DBI)

# Já houve embaralhamento nesta sessão? Lido do log. (Na rodada de teste,
# limpar_votos() apaga o log, e a sessão seguinte pode embaralhar de novo.)
votos_embaralhados <- function(con) {
  DBI::dbGetQuery(con,
    "select count(*)::int as n from log where evento = 'votos_embaralhados'")$n > 0L
}

# Destrói a ordem física da tabela votos (seção 6 do CLAUDE.md,
# invariante 11). Uma transação:
# - trava a urna e exige 'encerrada';
# - recusa se já embaralhou;
# - confere a integridade antes (e recusa se não bater);
# - recria votos em ordem aleatória;
# - confere a integridade depois (e desfaz tudo se não bater);
# - registra no log.
#
# Devolve list(ok = TRUE, antes, depois) ou list(ok = FALSE, motivo) com
# motivo em: urna_nao_configurada, urna_nao_encerrada, ja_embaralhado,
# integridade_divergente, erro_interno.
embaralhar_votos <- function(con) {
  recusar <- function(motivo) {
    stop(structure(class = c("urna_recusa", "error", "condition"),
                   list(message = motivo, call = NULL)))
  }

  DBI::dbBegin(con)

  tryCatch({
    u <- DBI::dbGetQuery(con, "select estado from urna where id = 1 for update")
    if (nrow(u) != 1L)             recusar("urna_nao_configurada")
    if (u$estado != "encerrada")   recusar("urna_nao_encerrada")
    if (votos_embaralhados(con))   recusar("ja_embaralhado")

    antes <- conferir_integridade(con)
    if (!isTRUE(antes$ok))         recusar("integridade_divergente")

    DBI::dbExecute(con,
      "create table votos_novo as select id, opcao from votos order by random()")
    DBI::dbExecute(con, "drop table votos")
    DBI::dbExecute(con, "alter table votos_novo rename to votos")
    DBI::dbExecute(con, "alter table votos add primary key (id)")
    # "create table as" não copia o NOT NULL da opção: recoloca.
    DBI::dbExecute(con, "alter table votos alter column opcao set not null")

    depois <- conferir_integridade(con)
    if (!isTRUE(depois$ok) || depois$votos != antes$votos) {
      recusar("integridade_divergente")
    }

    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('votos_embaralhados', $1)",
      list(sprintf("votos=%d integridade antes=ok depois=ok", depois$votos)))

    DBI::dbCommit(con)
    list(ok = TRUE, antes = antes, depois = depois)
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

# Apuração: total por chapa (inclusive as com zero voto), abstenções,
# votantes e aptos. Só com a urna encerrada e os votos já embaralhados.
#
# Devolve list(ok = TRUE, tabela, total_votos, votantes, aptos,
# integridade_ok) ou list(ok = FALSE, motivo) com motivo em:
# urna_nao_configurada, urna_nao_encerrada, votos_nao_embaralhados.
apurar <- function(con) {
  u <- DBI::dbGetQuery(con,
    "select estado, permite_abstencao from urna where id = 1")
  if (nrow(u) != 1L)              return(list(ok = FALSE, motivo = "urna_nao_configurada"))
  if (u$estado != "encerrada")    return(list(ok = FALSE, motivo = "urna_nao_encerrada"))
  if (!votos_embaralhados(con))   return(list(ok = FALSE, motivo = "votos_nao_embaralhados"))

  chapas <- DBI::dbGetQuery(con,
    "select numero::text as opcao, nome from chapas order by numero")
  contagem <- DBI::dbGetQuery(con,
    "select opcao, count(*)::int as n from votos group by opcao")

  opcoes <- chapas
  if (isTRUE(u$permite_abstencao) || "abstencao" %in% contagem$opcao) {
    opcoes <- rbind(opcoes, data.frame(opcao = "abstencao", nome = "Abstenção"))
  }
  # Opção gravada que não é chapa nem abstenção não deveria existir; se
  # existir, aparece na apuração em vez de sumir.
  estranhas <- setdiff(contagem$opcao, opcoes$opcao)
  if (length(estranhas)) {
    opcoes <- rbind(opcoes, data.frame(opcao = estranhas,
                                       nome = "OPÇÃO DESCONHECIDA"))
  }

  n <- contagem$n[match(opcoes$opcao, contagem$opcao)]
  opcoes$votos <- ifelse(is.na(n), 0L, n)

  i <- conferir_integridade(con)
  list(
    ok             = TRUE,
    tabela         = opcoes,
    total_votos    = sum(opcoes$votos),
    votantes       = i$votantes,
    aptos          = contagem_votacao(con)$aptos,
    integridade_ok = i$ok
  )
}

MOTIVOS_APURACAO <- c(
  urna_nao_configurada   = "A urna não está configurada neste banco.",
  urna_nao_encerrada     = "A urna ainda não foi encerrada.",
  ja_embaralhado         = "Os votos já foram embaralhados.",
  votos_nao_embaralhados = "Os votos ainda não foram embaralhados.",
  integridade_divergente = "INCIDENTE: votantes e votos não batem. Nada foi mexido.",
  erro_interno           = "Erro ao falar com o banco. Nada foi mexido; tente de novo."
)
