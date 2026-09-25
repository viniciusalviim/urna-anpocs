# Gera a linha URNA_MESARIO_HASH=... para o .Renviron.
#
# Rode no RStudio, com a pasta do projeto aberta:
#   source("dev/gerar_hash_mesario.R")
#
# A senha é pedida numa caixa e não fica gravada em lugar nenhum: só o hash
# sai na tela. Cole a linha no .Renviron e reinicie o R (Session > Restart R).
#
# A senha da ELEIÇÃO tem de ser diferente da usada na demonstração e na
# rodada de teste, e conhecida só pelo Vinicius e pela segunda pessoa
# treinada (checklist de produção, CLAUDE.md).

source("R/mesario.R")

pedir <- function(texto) {
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    rstudioapi::askForPassword(texto)
  } else if (interactive()) {
    readline(paste0(texto, " (vai aparecer na tela): "))
  } else {
    stop("Rode este script no RStudio (ou num R interativo), nao com Rscript.",
         call. = FALSE)
  }
}

senha <- pedir("Senha do mesario")
if (is.null(senha) || !nzchar(senha)) stop("Nenhuma senha digitada. Nada foi gerado.", call. = FALSE)
if (nchar(senha) < 10) stop("Use pelo menos 10 caracteres. Nada foi gerado.", call. = FALSE)

confirmacao <- pedir("Digite a mesma senha de novo")
if (!identical(senha, confirmacao)) stop("As duas senhas nao batem. Nada foi gerado.", call. = FALSE)

linha <- paste0("URNA_MESARIO_HASH=", codificar_hash_mesario(senha))
rm(senha, confirmacao)

cat("\nCole esta linha no .Renviron (substituindo a anterior, se houver):\n\n",
    linha, "\n\nDepois reinicie o R (Session > Restart R).\n", sep = "")
