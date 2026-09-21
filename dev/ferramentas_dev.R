# Ferramentas SO de desenvolvimento.
#
# Este arquivo fica em dev/ de proposito: o app nunca carrega nada daqui.
# Tudo o que apaga tabelas mora neste arquivo, e tudo passa pela trava
# exigir_banco_dev(), que le o carimbo gravado DENTRO do banco.

# Tabelas do sistema. A tabela 'ambiente' NAO esta aqui de proposito:
# o carimbo nunca e apagado.
TABELAS <- c("log", "votos", "votantes", "credenciais",
             "programas", "chapas", "urna")

exigir_banco_dev <- function(con) {
  amb <- ambiente_do_banco(con)

  if (is.na(amb)) {
    stop("Este banco nao tem carimbo de ambiente.\n",
         "Rode dev/01_preparar_banco.R antes.", call. = FALSE)
  }
  if (!identical(amb, "dev")) {
    stop("PARADO. Este banco esta carimbado como '", amb, "'.\n",
         "Esta operacao apaga tabelas e nao roda aqui.", call. = FALSE)
  }
  invisible(TRUE)
}

# Apaga todas as tabelas do sistema e recria vazias.
zerar_banco_dev <- function(con, caminho_schema) {
  exigir_banco_dev(con)
  DBI::dbExecute(con, paste("drop table if exists",
                            paste(TABELAS, collapse = ", "), "cascade"))
  executar_sql(con, caminho_schema)
  invisible(TRUE)
}

# n programas falsos. Um a cada 12 e Centro de Pesquisa, para o sistema ja
# nascer lidando com os dois tipos que o regimento preve.
programas_sinteticos <- function(n) {
  i <- seq_len(n)
  centro <- i %% 12 == 0
  data.frame(
    id           = sprintf("prog%03d", i),
    nome_oficial = ifelse(centro,
                          sprintf("Centro de Pesquisa de Teste %03d", i),
                          sprintf("Programa de Pos-Graduacao de Teste %03d", i)),
    tipo         = ifelse(centro, "centro", "ppg"),
    login        = sprintf("teste-%03d", i),
    stringsAsFactors = FALSE
  )
}
