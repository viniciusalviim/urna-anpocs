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

invisible(DBI::dbExecute(con,
  "insert into urna (id, estado, modo, permite_abstencao, aberta_em)
   values (1, 'aberta', 'teste', true, now())"))

source("dev/exemplos.R")
invisible(cadastrar_chapas_exemplo(con))

cat("\nUrna:\n")
print(DBI::dbGetQuery(con, "select estado, modo, permite_abstencao from urna"))
cat("\nChapas:\n")
print(DBI::dbGetQuery(con, "select numero, nome from chapas order by numero"))

DBI::dbDisconnect(con)

cat("\nPronto. Para entrar, use as senhas de", ARQUIVO_ATIVAS,
    "\n(as de", ARQUIVO_RESERVAS, "so entram depois de trocar_credencial())\n")
if (!identical(Sys.getenv("URNA_AMBIENTE"), "dev")) {
  cat("\nATENCAO: sem URNA_AMBIENTE=dev no .Renviron, a urna local mostra",
      "\n'mal configurada' e nao deixa entrar.\n")
}
