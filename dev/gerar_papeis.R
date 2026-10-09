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
SISTEMA        <- "TESTE"   # "TESTE" ou "PRODUCAO": define os arquivos abaixo
LOGO           <- "dev/logo_anpocs"   # sem extensão: .png ou .jpg

# Dois PDFs: os papéis da lista (um por programa) e os das 10 credenciais
# avulsas (ficam com a mesa).
ARQUIVO_ATIVAS  <- sprintf("saida/%s_PINS_ATIVOS_enviar_aos_coordenadores.csv", SISTEMA)
ARQUIVO_PDF     <- sprintf("saida/%s_papeis_credenciais.pdf", SISTEMA)
ARQUIVO_AVULSAS <- sprintf("saida/%s_PINS_AVULSAS_ATIVOS_guardar_com_a_mesa.csv", SISTEMA)
PDF_AVULSAS     <- sprintf("saida/%s_papeis_AVULSAS_guardar_com_a_mesa.pdf", SISTEMA)

stopifnot(SISTEMA %in% c("TESTE", "PRODUCAO"))

source("R/comprovante.R")
source("R/credenciais.R")
source("dev/papeis.R")

if (!nzchar(ENDERECO_URNA)) {
  stop("Preencha ENDERECO_URNA no topo de dev/gerar_papeis.R. Nada foi gerado.",
       call. = FALSE)
}
validar_endereco_urna(ENDERECO_URNA)
logo <- ler_logo(LOGO)   # sem o logo, para aqui

gerar <- function(csv, pdf) {
  senhas <- ler_senhas_ativas(csv)
  dir.create(dirname(pdf), showWarnings = FALSE)
  exigir_escrita(pdf)   # PDF aberto no leitor trava a escrita
  gerar_papeis_pdf(senhas, ENDERECO_URNA, pdf, teste = e_arquivo_de_teste(csv), logo = logo)
  cat(nrow(senhas), "papeis gerados em", pdf, "\n")
}

gerar(ARQUIVO_ATIVAS, ARQUIVO_PDF)
if (file.exists(ARQUIVO_AVULSAS)) {
  gerar(ARQUIVO_AVULSAS, PDF_AVULSAS)
} else {
  cat("ATENCAO: nao achei", ARQUIVO_AVULSAS, "- papeis das avulsas nao gerados.\n")
}

if (SISTEMA == "TESTE") cat("(sistema de teste: cada papel traz a faixa CREDENCIAL DE TESTE)\n")
cat("\nConfira um papel lendo o QR code com o celular antes de imprimir tudo.\n",
    "Os PDFs tem PINs: apague depois de imprimir.\n", sep = "")
