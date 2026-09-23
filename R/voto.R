# Urna ANPOCS 2026 — a transação do voto
#
# Este é o núcleo do sistema. Não altere sem que os testes em
# tests/testthat/test-voto.R continuem passando.

library(DBI)
library(openssl)

# Alfabeto sem caracteres ambíguos (sem I, O, 0, 1, l).
# 24 letras + 8 dígitos = 32 símbolos; 256 %% 32 == 0, logo sem viés.
ALFABETO <- c(setdiff(LETTERS, c("I", "O")), as.character(2:9))

gerar_codigo <- function(n = 12) {
  bytes <- as.integer(openssl::rand_bytes(n))
  paste(ALFABETO[bytes %% 32L + 1L], collapse = "")
}

formatar_codigo <- function(codigo, bloco = 4) {
  partes <- substring(codigo,
                      seq(1, nchar(codigo), bloco),
                      pmin(seq(bloco, nchar(codigo) + bloco - 1, bloco), nchar(codigo)))
  paste(partes, collapse = "-")
}

opcoes_validas <- function(con, permite_abstencao) {
  numeros <- DBI::dbGetQuery(con, "select numero::text as n from chapas order by numero")$n
  if (isTRUE(permite_abstencao)) c(numeros, "abstencao") else numeros
}

# Registra um voto em uma única transação.
#
# Devolve list(ok = TRUE, comprovante_id = "...") ou
# list(ok = FALSE, motivo = "...") com motivo em:
# urna_nao_configurada, urna_nao_aberta, credencial_invalida,
# opcao_invalida, ja_votou, erro_interno.
registrar_voto <- function(con, programa_id, credencial_id, opcao) {

  # O R só calcula os argumentos quando precisa deles. Se algum argumento for
  # ele mesmo uma consulta ao banco, ele seria calculado no meio da transação
  # e atropelaria a consulta em curso na mesma conexão. force() resolve isso
  # obrigando o cálculo a acontecer agora, antes de encostar no banco.
  force(programa_id)
  force(credencial_id)
  force(opcao)

  recusar <- function(motivo) {
    stop(structure(class = c("urna_recusa", "error", "condition"),
                   list(message = motivo, call = NULL)))
  }

  DBI::dbBegin(con)

  tryCatch({
    # FOR SHARE impede que a urna seja encerrada no meio desta transação.
    urna <- DBI::dbGetQuery(
      con, "select estado, permite_abstencao from urna where id = 1 for share")
    if (nrow(urna) != 1L)            recusar("urna_nao_configurada")
    if (urna$estado != "aberta")     recusar("urna_nao_aberta")

    # Só a credencial ativa vota (invariante 12). FOR SHARE impede que
    # trocar_credencial() a desative no meio desta transação.
    cred <- DBI::dbGetQuery(con,
      "select c.id
         from credenciais c
         join programas p on p.id = c.programa_id
        where c.id = $1 and c.programa_id = $2 and c.ativa and p.apto
          for share of c",
      list(credencial_id, programa_id))
    if (nrow(cred) != 1L)            recusar("credencial_invalida")

    if (!opcao %in% opcoes_validas(con, urna$permite_abstencao)) {
      recusar("opcao_invalida")
    }

    comprovante <- formatar_codigo(gerar_codigo(12))

    # A TRAVA. É o banco que recusa o segundo voto, não o R.
    # Não escreva um SELECT "já votou?" antes disto: entre o SELECT e o
    # INSERT cabem dois votos simultâneos.
    n <- DBI::dbExecute(con,
      "insert into votantes (programa_id, credencial_id, comprovante_id)
       values ($1, $2, $3)
       on conflict (programa_id) do nothing",
      list(programa_id, credencial_id, comprovante))
    if (n == 0L)                     recusar("ja_votou")

    DBI::dbExecute(con,
      "insert into votos (id, opcao) values (gen_random_uuid(), $1)",
      list(opcao))

    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('voto_registrado', $1)",
      list(programa_id))

    DBI::dbCommit(con)
    list(ok = TRUE, comprovante_id = comprovante)
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

# Verificação de integridade: votantes e votos têm de bater sempre.
# Alimenta o sinal verde/vermelho do painel do mesário.
conferir_integridade <- function(con) {
  r <- DBI::dbGetQuery(con,
    "select (select count(*) from votantes) as votantes,
            (select count(*) from votos)    as votos")
  list(votantes = r$votantes, votos = r$votos, ok = r$votantes == r$votos)
}
