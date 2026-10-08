# Votos simultâneos: vários processos, cada um com a sua conexão, entrando e
# votando ao mesmo tempo pelas mesmas funções da urna. Em escala pequena aqui;
# a simulação grande é dev/simular_carga.R.

test_that("votos simultâneos: um voto por programa, voto duplo recusado, integridade ok", {
  con <- banco_vazio(); on.exit(DBI::dbDisconnect(con))
  saida <- carregar_programas(con, programas_sinteticos(12))
  cadastrar_chapa(con, CHAPA_OFICIAL)
  DBI::dbExecute(con,
    "insert into urna (id, estado, modo, permite_abstencao, aberta_em)
     values (1, 'aberta', 'teste', true, now())")
  ativas <- separar_senhas(saida)$ativas

  r <- votar_em_paralelo(ativas, n_processos = 4, duplicados = 4,
                         raiz = normalizePath(file.path("..", "..")), espera = 2)

  expect_equal(nrow(r), 16)                       # 12 votos + 4 tentativas duplas
  aceitos <- tapply(r$ok, r$login, sum)
  expect_equal(length(aceitos), 12)
  expect_true(all(aceitos == 1))                  # exatamente um por programa
  expect_equal(sum(!r$ok), 4)
  expect_true(all(r$motivo[!r$ok] %in% c("ja_votou", "login:ja_votou")))
  expect_true(all(r$seg_login >= 0 & r$seg_voto >= 0))

  i <- conferir_integridade(con)
  expect_true(i$ok)
  expect_equal(i$votantes, 12L)
  expect_equal(i$votos, 12L)
})
