# Urna ANPOCS 2026 — leituras do painel do mesário
#
# Só contagens, nomes e horas. Nenhuma função daqui lê a tabela votos
# (invariante 9; o teste em test-apuracao.R confere).

library(DBI)

# Um programa por linha: login, nome, se é apto, a ordem da credencial ativa,
# se já votou e a que horas, e se entrou na urna (login aceito depois da
# abertura) sem ter votado ainda.
listar_programas <- function(con) {
  DBI::dbGetQuery(con,
    "select p.id as programa_id, p.login, p.nome_oficial, p.apto,
            c.ordem::int                 as credencial_ativa,
            (v.programa_id is not null)  as votou,
            v.votado_em,
            (v.programa_id is null and exists (
               select 1 from log l, urna u
                where u.id = 1 and u.aberta_em is not null
                  and l.evento = 'login_ok' and l.detalhe = p.id
                  and l.em >= u.aberta_em)) as entrou_sem_votar
       from programas p
       left join credenciais c on c.programa_id = p.id and c.ativa
       left join votantes v    on v.programa_id = p.id
      order by p.login")
}

# Quantos votaram, do total de aptos, e se votantes = votos.
contagem_votacao <- function(con) {
  aptos <- DBI::dbGetQuery(con,
    "select count(*)::int as n from programas where apto")$n
  i <- conferir_integridade(con)
  list(aptos = aptos, votantes = i$votantes, integridade_ok = i$ok)
}
