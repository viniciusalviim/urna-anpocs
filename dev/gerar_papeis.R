# Gera o PDF para imprimir: um papel por programa, com nome, login, PIN e
# um QR code que abre a urna (o mesmo endereço para todos).
#
# Roda SÓ no computador do responsável, como a geração dos PINs. O PDF
# contém PINs: não envie por e-mail, não deixe em pasta compartilhada e
# apague depois de imprimir. Os papéis que sobrarem são destruídos.
#
# Arquivo do sistema de teste (TESTE_...): cada papel sai com a faixa
# "CREDENCIAL DE TESTE / este PIN NÃO vale na eleição".
#
# Para rodar, na pasta do projeto:
#   Rscript dev/gerar_papeis.R

ENDERECO_URNA  <- ""   # endereço publicado da urna, começando com https://
ARQUIVO_ATIVAS <- "saida/TESTE_PINS_ATIVOS_enviar_aos_coordenadores.csv"
ARQUIVO_PDF    <- "saida/TESTE_papeis_credenciais.pdf"

source("R/comprovante.R")
source("R/credenciais.R")
source("dev/papeis.R")

if (!nzchar(ENDERECO_URNA)) {
  stop("Preencha ENDERECO_URNA no topo de dev/gerar_papeis.R. Nada foi gerado.",
       call. = FALSE)
}
validar_endereco_urna(ENDERECO_URNA)

senhas <- ler_senhas_ativas(ARQUIVO_ATIVAS)
teste  <- e_arquivo_de_teste(ARQUIVO_ATIVAS)

dir.create(dirname(ARQUIVO_PDF), showWarnings = FALSE)
exigir_escrita(ARQUIVO_PDF)   # PDF aberto no leitor trava a escrita

gerar_papeis_pdf(senhas, ENDERECO_URNA, ARQUIVO_PDF, teste = teste)

cat(nrow(senhas), "papeis gerados em", ARQUIVO_PDF, "\n")
if (teste) cat("(arquivo de teste: cada papel traz a faixa CREDENCIAL DE TESTE)\n")
cat("\nConfira um papel lendo o QR code com o celular antes de imprimir tudo.\n",
    "O PDF tem PINs: apague depois de imprimir.\n", sep = "")
