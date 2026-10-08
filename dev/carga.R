# Votos simultâneos, para ver se o banco e a transação do voto aguentam
# muita gente ao mesmo tempo. Usado por dev/simular_carga.R e pelos testes.
#
# Abre n_processos processos do R (pacote parallel, que vem com o R), cada
# um com a sua conexão ao banco de DEV. Todos esperam o mesmo instante de
# largada e então entram (autenticar) e votam (registrar_voto) pelas mesmas
# funções da urna. Uma parte dos programas recebe uma segunda tentativa de
# voto, num processo diferente, de propósito: o banco tem de recusá-la.
#
# Mede o banco e a transação. NÃO mede o servidor do Connect Cloud com
# navegadores de verdade.

# `credenciais`: data.frame com login e senha (o PIN ativo de cada programa).
# Devolve um data.frame com uma linha por tentativa: login, tentativa (1 ou
# 2), processo, ok, motivo, seg_login e seg_voto.
votar_em_paralelo <- function(credenciais, n_processos = 20, duplicados = 0,
                              raiz = ".", espera = 5,
                              opcoes = c("1", "abstencao")) {
  n <- nrow(credenciais)
  stopifnot(n > 0, n_processos >= 1, duplicados >= 0, duplicados <= n)

  tarefas <- data.frame(
    login     = credenciais$login,
    senha     = credenciais$senha,
    opcao     = sample(opcoes, n, replace = TRUE),
    tentativa = 1L,
    processo  = (seq_len(n) - 1L) %% n_processos + 1L,
    rodada    = (seq_len(n) - 1L) %/% n_processos,
    stringsAsFactors = FALSE
  )
  if (duplicados > 0) {
    # A segunda tentativa vai para o processo seguinte, na mesma "rodada":
    # as duas chegam ao banco praticamente juntas.
    dup <- tarefas[sample(n, duplicados), ]
    dup$tentativa <- 2L
    dup$processo  <- dup$processo %% n_processos + 1L
    tarefas <- rbind(tarefas, dup)
  }
  tarefas <- tarefas[order(tarefas$processo, tarefas$rodada, tarefas$tentativa), ]

  cl <- parallel::makeCluster(n_processos)
  on.exit(parallel::stopCluster(cl), add = TRUE)

  raiz <- normalizePath(raiz, winslash = "/")
  parallel::clusterExport(cl, "raiz", envir = environment())
  parallel::clusterEvalQ(cl, {
    for (f in c("db.R", "voto.R", "credenciais.R", "login.R")) {
      source(file.path(raiz, "R", f))
    }
    con <- conectar()          # URNA_PG_*: o banco de dev
    exigir_ambiente(con, "dev")
    NULL
  })

  largada <- Sys.time() + espera

  trabalho <- function(b, largada) {
    while (Sys.time() < largada) Sys.sleep(0.01)   # processo à parte: pode esperar
    linhas <- lapply(seq_len(nrow(b)), function(i) {
      t0 <- Sys.time()
      a  <- autenticar(con, b$login[i], b$senha[i])
      t1 <- Sys.time()
      r  <- if (isTRUE(a$ok)) {
        registrar_voto(con, a$programa_id, a$credencial_id, b$opcao[i])
      } else {
        list(ok = FALSE, motivo = paste0("login:", a$motivo))
      }
      t2 <- Sys.time()
      data.frame(login = b$login[i], tentativa = b$tentativa[i],
                 processo = b$processo[i], ok = isTRUE(r$ok),
                 motivo = if (isTRUE(r$ok)) "" else r$motivo,
                 seg_login = as.numeric(difftime(t1, t0, units = "secs")),
                 seg_voto  = as.numeric(difftime(t2, t1, units = "secs")),
                 stringsAsFactors = FALSE)
    })
    do.call(rbind, linhas)
  }
  environment(trabalho) <- globalenv()   # nos processos, `con` e as funções são globais

  res <- parallel::parLapply(cl, split(tarefas, tarefas$processo), trabalho,
                             largada = largada)
  parallel::clusterEvalQ(cl, DBI::dbDisconnect(con))

  out <- do.call(rbind, res)
  rownames(out) <- NULL
  out
}
