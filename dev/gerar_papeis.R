# Gera o PDF para imprimir: um papel por programa, com nome, login, senha e
# um QR code que abre a urna (o mesmo endereço para todos).
#
# Roda SÓ no computador do responsável, como a geração das senhas. O PDF
# contém senhas: não envie por e-mail, não deixe em pasta compartilhada e
# apague depois de imprimir. Os papéis que sobrarem são destruídos.
#
# Para rodar, na pasta do projeto:
#   Rscript dev/gerar_papeis.R

ENDERECO_URNA  <- ""   # endereço publicado da urna, começando com https://
ARQUIVO_ATIVAS <- "saida/RODADA_senhas_ATIVAS_enviar_aos_participantes.csv"
ARQUIVO_PDF    <- "saida/papeis_credenciais.pdf"

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
    "O PDF tem senhas: apague depois de imprimir.\n", sep = "")
