# Helper dos testes.
#
# Tudo o que apaga tabelas esta em dev/ferramentas_dev.R e passa pela trava
# que le o carimbo gravado DENTRO do banco. Se o banco estiver carimbado como
# "producao", os testes param, nao importa o que diga o .Renviron.

# Carrega todos os arquivos de R/. Arquivo novo em R/ entra sozinho.
for (f in sort(list.files(file.path("..", "..", "R"),
                          pattern = "\\.R$", full.names = TRUE))) {
  source(f)
}
source(file.path("..", "..", "dev", "ferramentas_dev.R"))

CAMINHO_SCHEMA <- file.path("..", "..", "sql", "001_schema.sql")

recriar_banco <- function(con) zerar_banco_dev(con, CAMINHO_SCHEMA)

# 3 programas, 3 credenciais cada, 2 chapas, urna aberta em modo teste.
# A senha_hash aqui e marcador: os testes de voto nao passam pelo login.
semear <- function(con, estado = "aberta", permite_abstencao = TRUE) {
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao, aberta_em)
     values (1, $1, 'teste', $2, now())", list(estado, permite_abstencao))

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

# Banco com as tabelas vazias.
banco_vazio <- function() {
  con <- conectar()
  recriar_banco(con)
  con
}

# Banco com a semente dos testes de voto.
banco_limpo <- function(...) {
  con <- banco_vazio()
  semear(con, ...)
  con
}
