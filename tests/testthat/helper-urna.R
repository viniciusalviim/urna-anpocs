# Helper dos testes.
#
# ATENCAO: recriar_banco() APAGA todas as tabelas.
#
# A trava que impede isso de acontecer no banco errado le o carimbo gravado
# DENTRO do banco, nao uma configuracao do computador. Se o banco estiver
# carimbado como "producao", os testes param, nao importa o que diga o
# .Renviron.

source(file.path("..", "..", "R", "db.R"))
source(file.path("..", "..", "R", "voto.R"))

# Tabelas do sistema. A tabela 'ambiente' NAO esta aqui de proposito:
# o carimbo nunca e apagado.
TABELAS <- c("log", "votos", "votantes", "credenciais",
             "programas", "chapas", "urna")

exigir_banco_dev <- function(con) {
  amb <- ambiente_do_banco(con)

  if (is.na(amb)) {
    stop("Este banco nao tem carimbo de ambiente.\n",
         "Rode dev/01_preparar_banco.R antes de rodar os testes.")
  }
  if (!identical(amb, "dev")) {
    stop("PARADO. Este banco esta carimbado como '", amb, "'.\n",
         "Os testes apagam todas as tabelas e nao rodam aqui.")
  }
  invisible(TRUE)
}

recriar_banco <- function(con) {
  exigir_banco_dev(con)
  DBI::dbExecute(con, paste("drop table if exists",
                            paste(TABELAS, collapse = ", "), "cascade"))
  executar_sql(con, file.path("..", "..", "sql", "001_schema.sql"))
  invisible(TRUE)
}

# 3 programas, 3 credenciais cada, 2 chapas, urna aberta em modo teste.
# A senha_hash aqui e marcador: autenticacao e a etapa 3.
semear <- function(con, estado = "aberta", permite_branco = TRUE) {
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_branco, aberta_em)
     values (1, $1, 'teste', $2, now())", list(estado, permite_branco))

  DBI::dbExecute(con,
    "insert into chapas (numero, nome, membros) values
     (1, 'Chapa Um',  '[{\"nome\":\"Fulana\",\"cargo\":\"Presidencia\"}]'::jsonb),
     (2, 'Chapa Dois','[{\"nome\":\"Beltrano\",\"cargo\":\"Presidencia\"}]'::jsonb)")

  for (i in 1:3) {
    DBI::dbExecute(con,
      "insert into programas (id, nome_oficial, tipo, login, apto)
       values ($1, $2, 'ppg', $3, true)",
      list(sprintf("prog%02d", i),
           sprintf("Programa de Teste %d", i),
           sprintf("teste-%02d", i)))
    for (o in 1:3) {
      DBI::dbExecute(con,
        "insert into credenciais (programa_id, ordem, senha_hash)
         values ($1, $2, 'hash-de-teste')",
        list(sprintf("prog%02d", i), o))
    }
  }
  invisible(TRUE)
}

credenciais_de <- function(con, programa_id) {
  DBI::dbGetQuery(con,
    "select id from credenciais where programa_id = $1 order by ordem",
    list(programa_id))$id
}

banco_limpo <- function(...) {
  con <- conectar()
  recriar_banco(con)
  semear(con, ...)
  con
}
