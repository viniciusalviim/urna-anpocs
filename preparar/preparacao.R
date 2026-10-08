# Urna ANPOCS 2026 — preparação do banco com a lista oficial
#
# Usado por preparar/preparar_banco.R, o mesmo script para o sistema de
# TESTE e para o sistema FINAL. Roda só no computador do responsável: lê a
# planilha (pacote readxl, que não vai para o Connect Cloud) e gera os PINs.
#
# Depende de R/db.R, R/credenciais.R e preparar/chapas.R.

# ---- a lista oficial -------------------------------------------------------

# Correções aprovadas pelo responsável (08/10). Cada uma só é aplicada se o
# texto encontrado for exatamente o esperado ("de"); se a lista mudar, a
# preparação para em vez de corrigir às cegas.
CORRECOES_LISTA <- data.frame(
  login = c("usp-iri", "ufscar-ppgas", "unesp-ar-ppgcs", "ufpa-naea",
            "puc-ppgcs", "puc-iri", "puc-rs-ppgscp", "puc-sp-ppgcs"),
  campo = c("nome", "nome", "universidade", "nome",
            "universidade", "universidade", "universidade", "universidade"),
  de    = c("Programa de Pós-Graduação de Pós-Graduação em Relações Internacionais",
            "Programa de Pós-Graduação em Antropologia SociaL",
            "UNESP-Araquara",
            "Núcleo de Altos Estudos Amazonicos",
            "PUC", "PUC", "PUC", "PUC"),
  para  = c("Programa de Pós-Graduação em Relações Internacionais",
            "Programa de Pós-Graduação em Antropologia Social",
            "UNESP-Araraquara",
            "Núcleo de Altos Estudos Amazônicos",
            "PUC-MG", "PUC-MG", "PUC-RS", "PUC-SP"),
  stringsAsFactors = FALSE
)

# Espaço não separável (\u00a0) vira espaço comum; espaços repetidos viram
# um; as pontas são aparadas.
limpar_texto <- function(x) {
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("[[:space:]]+", " ", x)
  trimws(x)
}

# A planilha tem 4 colunas, sem cabeçalho: UF, universidade, nome do
# programa, login. Devolve um data.frame com id (= login), login (em
# minúsculas), nome_oficial ("<nome> – <universidade>"), tipo (ppg ou
# centro), uf, universidade e nome.
limpar_lista <- function(bruta, correcoes = CORRECOES_LISTA) {
  bruta <- as.data.frame(bruta, stringsAsFactors = FALSE)
  if (ncol(bruta) != 4L) {
    stop("A lista tem ", ncol(bruta), " colunas; eram esperadas 4 (UF, universidade, ",
         "nome do programa, login). Nada foi feito.", call. = FALSE)
  }
  if (nrow(bruta) == 0L) stop("A lista está vazia. Nada foi feito.", call. = FALSE)

  l <- data.frame(
    uf           = limpar_texto(bruta[[1]]),
    universidade = limpar_texto(bruta[[2]]),
    nome         = limpar_texto(bruta[[3]]),
    login        = tolower(limpar_texto(bruta[[4]])),
    stringsAsFactors = FALSE
  )

  vazia <- rowSums(is.na(l) | l == "") > 0
  if (any(vazia)) {
    stop("Célula vazia na(s) linha(s) ", paste(which(vazia), collapse = ", "),
         " da lista. Nada foi feito.", call. = FALSE)
  }

  for (i in seq_len(nrow(correcoes))) {
    cr <- correcoes[i, ]
    k <- which(l$login == cr$login)
    atual <- if (length(k) == 1L) l[[cr$campo]][k] else "<login não encontrado>"
    if (length(k) != 1L || !identical(atual, cr$de)) {
      stop("Correção não aplicada (login ", cr$login, ", ", cr$campo, "): esperado '",
           cr$de, "', encontrado '", atual, "'. A lista mudou? Nada foi feito.",
           call. = FALSE)
    }
    l[[cr$campo]][k] <- cr$para
  }

  ruins <- l$login[!grepl("^[a-z0-9-]+$", l$login)]
  if (length(ruins)) {
    stop("Login com caractere inválido: ", paste(ruins, collapse = ", "),
         ". Nada foi feito.", call. = FALSE)
  }
  rep <- unique(l$login[duplicated(l$login)])
  if (length(rep)) {
    stop("Login repetido na lista: ", paste(rep, collapse = ", "),
         ". Nada foi feito.", call. = FALSE)
  }

  l$nome_oficial <- paste(l$nome, "\u2013", l$universidade)
  rep <- unique(l$nome_oficial[duplicated(l$nome_oficial)])
  if (length(rep)) {
    stop("Nomes oficiais repetidos (o comprovante não distinguiria os programas): ",
         paste(rep, collapse = " | "), ". Nada foi feito.", call. = FALSE)
  }

  # Conferido pelo responsável: os 15 sem "Programa", "Mestrado" ou
  # "Doutorado" no nome são centros.
  l$tipo <- ifelse(grepl("Programa|Mestrado|Doutorado", l$nome), "ppg", "centro")
  l$id   <- l$login

  l[, c("id", "login", "nome_oficial", "tipo", "uf", "universidade", "nome")]
}

ler_lista_oficial <- function(arquivo) {
  if (!file.exists(arquivo)) {
    stop("Lista oficial não encontrada: ", arquivo, call. = FALSE)
  }
  bruta <- suppressMessages(readxl::read_excel(arquivo, col_names = FALSE,
                                               col_types = "text"))
  limpar_lista(bruta)
}

# ---- os arquivos de PINs ---------------------------------------------------

# O nome diz de qual sistema são: TESTE_..., PRODUCAO_... (DEV_... nos testes).
arquivos_de_pins <- function(ambiente, pasta = "saida") {
  stopifnot(length(ambiente) == 1L, ambiente %in% AMBIENTES)
  p <- toupper(ambiente)
  c(ativas   = file.path(pasta, paste0(p, "_PINS_ATIVOS_enviar_aos_coordenadores.csv")),
    reservas = file.path(pasta, paste0(p, "_PINS_RESERVAS_guardar_com_a_mesa.csv")))
}

# ---- a preparação ----------------------------------------------------------

# Prepara um banco vazio (ou recém-criado) para o ambiente pedido:
# carimbo, tabelas, chapa única, urna FECHADA, programas e PINs.
#
# Recusa, sem mexer em nada:
# - banco com carimbo de outro ambiente;
# - banco que já tem programas (rodar de novo geraria PINs novos, e os já
#   entregues deixariam de valer).
preparar_banco <- function(con, ambiente, lista, chapa, arquivos,
                           caminho_schema = "sql/001_schema.sql") {
  stopifnot(length(ambiente) == 1L, ambiente %in% AMBIENTES)

  amb <- ambiente_do_banco(con)
  if (!is.na(amb) && !identical(amb, ambiente)) {
    stop("PARADO. Este banco está carimbado como '", amb, "', e a preparação ",
         "foi pedida para '", ambiente, "'. Confira as variáveis ",
         prefixo_do_ambiente(ambiente), "_* no .Renviron. Nada foi feito.",
         call. = FALSE)
  }

  tem_tabelas <- !is.na(DBI::dbGetQuery(con,
    "select to_regclass('public.programas')::text as t")$t)
  if (tem_tabelas) {
    n <- DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n
    if (n > 0L) {
      stop("Este banco já foi preparado: tem ", n, " programas. Rodar de novo ",
           "geraria PINs novos, e os já entregues deixariam de valer. ",
           "Nada foi feito.", call. = FALSE)
    }
  }

  validar_chapa(chapa)
  exigir_escrita(arquivos)   # antes de gerar PINs: Excel aberto trava a escrita

  if (is.na(amb)) marcar_ambiente(con, ambiente)
  exigir_ambiente(con, ambiente)
  if (!tem_tabelas) executar_sql(con, caminho_schema)

  if (DBI::dbGetQuery(con, "select count(*)::int as n from chapas")$n == 0L) {
    cadastrar_chapa(con, chapa)
  }
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao)
     values (1, 'fechada', $1, true)
     on conflict (id) do nothing",
    list(if (identical(ambiente, "producao")) "oficial" else "teste"))

  saida <- carregar_programas(con, lista)
  s <- separar_senhas(saida)
  utils::write.csv(s$ativas,   arquivos[["ativas"]],   row.names = FALSE, fileEncoding = "UTF-8")
  utils::write.csv(s$reservas, arquivos[["reservas"]], row.names = FALSE, fileEncoding = "UTF-8")

  list(programas = length(unique(saida$login)),
       ativas    = nrow(s$ativas),
       reservas  = nrow(s$reservas),
       arquivos  = arquivos)
}
