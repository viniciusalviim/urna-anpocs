-- Urna ANPOCS 2026 — esquema
-- Requer PostgreSQL 13+ (gen_random_uuid() é nativo a partir do 13).

create table programas (
  id           text primary key,
  nome_oficial text not null,
  tipo         text not null check (tipo in ('ppg','centro')),
  login        text not null unique,
  apto         boolean not null default true
);

create table credenciais (
  id          bigserial primary key,
  programa_id text not null references programas(id),
  ordem       smallint not null check (ordem between 1 and 3),
  senha_hash  text not null,
  unique (programa_id, ordem)
);

-- Quem votou. Documento público para a Comissão. NÃO contém o voto.
create table votantes (
  programa_id    text primary key references programas(id),
  credencial_id  bigint not null references credenciais(id),
  votado_em      timestamptz not null default now(),
  comprovante_id text not null unique
);

-- O voto. Sem ligação com votantes. Sem tempo. Sem sequência.
-- INVARIANTE 4: estas duas colunas são as únicas que esta tabela pode ter.
create table votos (
  id    uuid primary key,
  opcao text not null
);

create table urna (
  id             smallint primary key default 1 check (id = 1),
  estado         text not null check (estado in ('fechada','aberta','encerrada')),
  modo           text not null check (modo   in ('teste','oficial')),
  permite_branco boolean not null default true,
  aberta_em      timestamptz,
  encerrada_em   timestamptz
);

create table chapas (
  numero  smallint primary key,
  nome    text not null,
  membros jsonb not null   -- [{"nome": "...", "cargo": "..."}, ...]
);

create table log (
  id      bigserial primary key,
  em      timestamptz not null default now(),
  evento  text not null,
  detalhe text            -- nunca conteúdo de voto
);

create index on credenciais (programa_id);
create index on votantes (votado_em);
