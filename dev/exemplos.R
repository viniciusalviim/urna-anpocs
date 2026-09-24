# Dados de exemplo, usados no dev e na rodada de teste. Nada aqui é real.

# Os 60 participantes da rodada de teste: logins rodada-01 a rodada-60.
programas_rodada <- function(n = 60) {
  i <- seq_len(n)
  data.frame(
    id           = sprintf("rod%02d", i),
    nome_oficial = sprintf("Participante da rodada %02d", i),
    tipo         = "ppg",
    login        = sprintf("rodada-%02d", i),
    stringsAsFactors = FALSE
  )
}

# As duas chapas de exemplo, iguais no dev e na rodada.
cadastrar_chapas_exemplo <- function(con) {
  DBI::dbExecute(con, "
    insert into chapas (numero, nome, membros) values
    (1, 'Chapa Exemplo Um', '[
       {\"nome\": \"Ana Ficticia\",     \"cargo\": \"Presidencia\"},
       {\"nome\": \"Bruno Inventado\",  \"cargo\": \"Secretaria Executiva\"},
       {\"nome\": \"Carla Imaginaria\", \"cargo\": \"Conselho Fiscal\"}
     ]'::jsonb),
    (2, 'Chapa Exemplo Dois', '[
       {\"nome\": \"Diego Suposto\",    \"cargo\": \"Presidencia\"},
       {\"nome\": \"Elisa Hipotetica\", \"cargo\": \"Secretaria Executiva\"},
       {\"nome\": \"Fabio Provisorio\", \"cargo\": \"Conselho Fiscal\"}
     ]'::jsonb)")
}
