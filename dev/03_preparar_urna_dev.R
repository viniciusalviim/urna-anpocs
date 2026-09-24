# Prepara o banco de desenvolvimento para testar a urna NA MAO:
# 119 programas sinteticos, CSVs novos com as senhas (ativas e reservas),
# urna aberta, duas chapas.
#
# Rode este script sempre antes de abrir o app para testar. Os testes
# automaticos apagam o banco inteiro a cada rodada, entao depois de rodar
# test_dir() o CSV antigo deixa de valer.

# 1. Programas e senhas (e o mesmo script da etapa 2)
source("dev/02_carregar_programas.R")

# 2. Urna aberta e chapas de mentira
con <- conectar()
exigir_banco_dev(con)

DBI::dbExecute(con,
  "insert into urna (id, estado, modo, permite_abstencao, aberta_em)
   values (1, 'aberta', 'teste', true, now())")

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

cat("\nUrna:\n")
print(DBI::dbGetQuery(con, "select estado, modo, permite_abstencao from urna"))
cat("\nChapas:\n")
print(DBI::dbGetQuery(con, "select numero, nome from chapas order by numero"))

DBI::dbDisconnect(con)

cat("\nPronto. Para entrar, use as senhas de", ARQUIVO_ATIVAS,
    "\n(as de", ARQUIVO_RESERVAS, "so entram depois de trocar_credencial())\n")
