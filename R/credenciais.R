# Urna ANPOCS 2026 — credenciais
#
# A senha de cada credencial e um PIN de 4 numeros (1000 a 9999, nenhum
# comeca com zero), por decisao do responsavel (08/10). Os 3 PINs de um
# programa sao diferentes entre si.
#
# O banco NUNCA guarda o PIN. Guarda so o hash: uma impressao digital que
# serve para conferir um PIN digitado, mas nao permite reconstrui-lo.
# Os PINs em texto existem uma unica vez, no data.frame devolvido por
# carregar_programas(), que vira o CSV entregue a secretaria.

library(DBI)
library(sodium)
library(openssl)

# PIN de 1000 a 9999 (9000 valores): nenhum comeca com zero, que o Excel
# apagaria. Um inteiro de 0 a 65535 (dois bytes aleatorios) vira
# 1000 + (resto da divisao por 9000), mas so de 0 a 62999: ai cada PIN
# aparece exatamente 7 vezes. De 63000 em diante devolve NA, e sorteia-se de
# novo. Sem isso, os PINs de 1000 a 3535 sairiam mais do que os outros.
pin_de_inteiro <- function(v) {
  ifelse(v < 63000, sprintf("%04d", 1000L + as.integer(v) %% 9000L), NA_character_)
}

gerar_pin <- function() {
  repeat {
    b <- as.integer(openssl::rand_bytes(2))
    p <- pin_de_inteiro(b[1] * 256L + b[2])
    if (!is.na(p)) return(p)
  }
}

# Os PINs de um programa: diferentes entre si, para que trocar para a
# reserva nunca "troque" para o mesmo PIN.
gerar_pins_programa <- function(n = 3L) {
  repeat {
    p <- vapply(seq_len(n), function(i) gerar_pin(), character(1))
    if (!anyDuplicated(p)) return(p)
  }
}

# Tolerancia de digitacao: minusculas, hifen e espacos nao importam. Um PIN
# digitado com menos de 4 numeros ganha zeros a esquerda. Os PINs gerados
# desde 08/10 nunca comecam com zero, entao isso nao muda nada para eles;
# fica por seguranca (um PIN antigo como "0427" aberto no Excel vira 427).
# Nao ha ambiguidade, porque todo PIN tem 4 numeros.
normalizar_senha <- function(senha) {
  s <- toupper(gsub("[^A-Za-z0-9]", "", senha))
  curto <- !is.na(s) & grepl("^[0-9]{1,3}$", s)
  s[curto] <- formatC(as.integer(s[curto]), width = 4, flag = "0")
  s
}

hash_senha <- function(senha) {
  sodium::password_store(normalizar_senha(senha))
}

verificar_senha <- function(senha, hash) {
  s <- normalizar_senha(senha)
  if (length(s) != 1L || is.na(s) || !nzchar(s)) return(FALSE)
  isTRUE(tryCatch(sodium::password_verify(hash, s), error = function(e) FALSE))
}

# Carrega os programas e cria 3 credenciais para cada um: a 1 ativa, a 2 e a
# 3 reservas inativas (ver trocar_credencial()), cada uma com um PIN.
#
# 'programas' e um data.frame com as colunas: id, nome_oficial, tipo, login.
# Devolve um data.frame com os PINs EM TEXTO (login, nome_oficial, tipo,
# ordem, senha, ativa; a coluna senha e o PIN). Esse objeto e o unico lugar
# onde eles existem: grave em CSV (separar_senhas) e entregue. Nao ha como
# recupera-los depois.
#
# So roda em banco sem programas. Rodar de novo geraria PINs novos e o banco
# deixaria de bater com o CSV ja entregue.
carregar_programas <- function(con, programas) {
  colunas <- c("id", "nome_oficial", "tipo", "login")
  faltando <- setdiff(colunas, names(programas))
  if (length(faltando)) stop("Faltam colunas: ", paste(faltando, collapse = ", "))
  programas <- as.data.frame(programas)[, colunas]

  if (nrow(programas) == 0L)          stop("Nenhum programa para carregar.")
  if (anyDuplicated(programas$id))    stop("Ha ids repetidos na lista de programas.")
  if (anyDuplicated(programas$login)) stop("Ha logins repetidos na lista de programas.")

  recusar_se_ja_carregado <- function() {
    n <- DBI::dbGetQuery(con, "select count(*)::int as n from programas")$n
    if (n > 0L) {
      stop("A tabela programas ja tem ", n, " linhas. A carga so roda em ",
           "banco vazio: gerar senhas de novo deixaria o banco diferente do ",
           "CSV entregue.", call. = FALSE)
    }
  }

  # Checagem rapida antes de gastar tempo gerando hashes...
  recusar_se_ja_carregado()

  cred <- data.frame(
    programa_id = rep(programas$id, each = 3L),
    ordem       = rep(1:3, times = nrow(programas)),
    stringsAsFactors = FALSE
  )
  cred$ativa      <- cred$ordem == 1L
  # 3 PINs diferentes por programa, na ordem 1, 2, 3 de cada um
  cred$senha      <- unlist(lapply(seq_len(nrow(programas)),
                                   function(i) gerar_pins_programa(3L)))
  cred$senha_hash <- vapply(cred$senha, hash_senha, character(1), USE.NAMES = FALSE)

  DBI::dbBegin(con)
  tryCatch({
    # ...e de novo dentro da transacao, que e a que vale.
    recusar_se_ja_carregado()

    DBI::dbAppendTable(con, "programas", programas)
    DBI::dbAppendTable(con, "credenciais",
                       cred[, c("programa_id", "ordem", "senha_hash", "ativa")])
    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('credenciais_geradas', $1)",
      list(sprintf("%d programas, %d credenciais", nrow(programas), nrow(cred))))

    DBI::dbCommit(con)
  }, error = function(e) {
    DBI::dbRollback(con)
    stop(conditionMessage(e), call. = FALSE)
  })

  i <- match(cred$programa_id, programas$id)
  data.frame(
    login        = programas$login[i],
    nome_oficial = programas$nome_oficial[i],
    tipo         = programas$tipo[i],
    ordem        = cred$ordem,
    senha        = cred$senha,
    ativa        = cred$ativa,
    stringsAsFactors = FALSE
  )
}

# Separa a saída de carregar_programas() nos dois arquivos entregues:
# - ativas:   uma por programa, a que a secretaria envia aos coordenadores;
# - reservas: as outras duas, que ficam guardadas com a mesa.
separar_senhas <- function(saida) {
  colunas <- c("login", "nome_oficial", "tipo", "ordem", "senha")
  list(
    ativas   = saida[saida$ativa,  colunas],
    reservas = saida[!saida$ativa, colunas]
  )
}

# Confere ANTES de gerar senhas que dá para escrever em todos os arquivos.
# Se um deles estiver aberto no Excel, a escrita falharia DEPOIS da carga,
# e as senhas ficariam só no banco, em forma de hash, perdidas para sempre.
exigir_escrita <- function(caminhos) {
  for (arq in caminhos) {
    ok <- tryCatch({
      f <- file(arq, "a"); close(f); TRUE
    }, error = function(e) FALSE, warning = function(e) FALSE)
    if (!ok) {
      stop("Nao consigo escrever em ", arq,
           ".\nO arquivo esta aberto em outro programa (Excel?) ou a pasta ",
           "nao existe. Feche e rode de novo.\nNada foi gerado.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

# Troca a credencial ativa de um programa pela próxima reserva (ex.: senha
# mandada ao e-mail errado). Numa transação: desativa a ativa e ativa a de
# ordem seguinte. As reservas são usadas em ordem, e uma credencial que já foi
# ativa nunca volta a ser.
#
# Devolve list(ok = TRUE, credencial_id, ordem) com a credencial que passou a
# valer, ou list(ok = FALSE, motivo) com motivo em:
# programa_inexistente, ja_votou, sem_credencial_ativa, sem_reserva,
# erro_interno.
trocar_credencial <- function(con, programa_id) {
  force(programa_id)

  recusar <- function(motivo) {
    stop(structure(class = c("urna_recusa", "error", "condition"),
                   list(message = motivo, call = NULL)))
  }

  DBI::dbBegin(con)

  tryCatch({
    # FOR UPDATE trava as credenciais do programa: um voto em curso com a
    # credencial ativa (que a trava FOR SHARE em registrar_voto) termina
    # antes, e a conferência de "já votou" abaixo já o enxerga.
    cred <- DBI::dbGetQuery(con,
      "select id, ordem, ativa from credenciais
        where programa_id = $1 order by ordem for update",
      list(programa_id))
    if (nrow(cred) == 0L)            recusar("programa_inexistente")

    votou <- DBI::dbGetQuery(con,
      "select count(*)::int as n from votantes where programa_id = $1",
      list(programa_id))$n
    if (votou > 0L)                  recusar("ja_votou")

    atual <- cred[cred$ativa, ]
    if (nrow(atual) != 1L)           recusar("sem_credencial_ativa")

    proxima <- cred[cred$ordem > atual$ordem, ]
    if (nrow(proxima) == 0L)         recusar("sem_reserva")
    proxima <- proxima[1, ]

    # Nesta ordem: o índice único não aceita duas ativas nem por um instante.
    DBI::dbExecute(con, "update credenciais set ativa = false where id = $1",
                   list(atual$id))
    DBI::dbExecute(con, "update credenciais set ativa = true where id = $1",
                   list(proxima$id))

    DBI::dbExecute(con,
      "insert into log (evento, detalhe) values ('credencial_trocada', $1)",
      list(sprintf("%s: credencial %d -> %d", programa_id,
                   as.integer(atual$ordem), as.integer(proxima$ordem))))

    DBI::dbCommit(con)
    list(ok = TRUE, credencial_id = proxima$id, ordem = proxima$ordem)
  },

  urna_recusa = function(e) {
    DBI::dbRollback(con)
    list(ok = FALSE, motivo = conditionMessage(e))
  },

  error = function(e) {
    DBI::dbRollback(con)
    list(ok = FALSE, motivo = "erro_interno", detalhe = conditionMessage(e))
  })
}
