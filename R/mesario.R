# Urna ANPOCS 2026 — senha do mesário (acesso ao painel)
#
# Só o hash fica guardado, na variável de ambiente URNA_MESARIO_HASH:
# no .Renviron local e, se o painel for publicado, nas variáveis secretas do
# Connect Cloud. O hash vai em hexadecimal porque o do sodium tem vários "$",
# que o .Renviron poderia confundir com referência a outra variável.
#
# Gere a linha do .Renviron com dev/gerar_hash_mesario.R.

library(sodium)

codificar_hash_mesario <- function(senha) {
  paste(as.character(charToRaw(sodium::password_store(senha))), collapse = "")
}

decodificar_hex <- function(hex) {
  if (length(hex) != 1L || is.na(hex) || !nzchar(hex)) return(NA_character_)
  if (!grepl("^([0-9a-f]{2})+$", hex)) return(NA_character_)
  pares <- substring(hex, seq(1, nchar(hex), 2), seq(2, nchar(hex), 2))
  bytes <- as.raw(strtoi(pares, 16L))
  if (any(bytes == as.raw(0))) return(NA_character_)
  rawToChar(bytes)
}

mesario_configurado <- function(hash_hex = Sys.getenv("URNA_MESARIO_HASH")) {
  !is.na(decodificar_hex(hash_hex))
}

# Senha exata: sem tolerância de caixa ou espaços (ao contrário das senhas
# dos votantes, que são sorteadas e digitadas no celular).
verificar_senha_mesario <- function(senha, hash_hex = Sys.getenv("URNA_MESARIO_HASH")) {
  if (length(senha) != 1L || is.na(senha) || !nzchar(senha)) return(FALSE)
  h <- decodificar_hex(hash_hex)
  if (is.na(h)) return(FALSE)
  isTRUE(tryCatch(sodium::password_verify(h, senha), error = function(e) FALSE))
}
