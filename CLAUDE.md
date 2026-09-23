# Urna ANPOCS 2026

Sistema de votação para a eleição do Conselho Diretivo e do Conselho Fiscal
da ANPOCS, biênio 2027–2028.

**Esta é uma eleição real, com resultado vinculante, e pode ser
judicializada.** Não é um simulador, não é material didático. Quando houver
dúvida entre uma solução elegante e uma solução auditável, escolha a
auditável.

Equipe: uma pessoa (Vinicius), sem TI na associação. Tudo precisa ser
simples o bastante para uma pessoa operar sob pressão, e explicável a uma
comissão eleitoral que não programa.

---

## 1. Fatos fixos

| | |
|---|---|
| Data | 9 de outubro de 2026, sexta, 19h30 (Brasília) |
| Contexto | 51ª Assembleia Geral Ordinária, formato híbrido |
| Janela | ~30 minutos, abertura e fechamento manuais pelo mesário |
| Eleitores | até 119 Programas de Pós-Graduação **e Centros de Pesquisa** |
| Voto | 1 por associado, exercido pelo Coordenador(a) ou Vice em exercício |
| Cédula | chapas numeradas (1..N) + branco |
| Credenciais | 3 por programa; 1 distribuída, 2 de reserva |

Duas datas do regimento travam o cronograma:

- **25/09** — prazo de inscrição das chapas. Só depois se sabe quantas
  opções a cédula tem e quais os nomes.
- **28/09** — a ANPOCS entrega a lista oficial de aptos a votar.

Logo: **todo o sistema precisa estar pronto e testado com dados sintéticos
antes de 28/09.** As credenciais reais são geradas depois, e só depois.

---

## 2. Stack

- R + Shiny (`bslib` para UI)
- PostgreSQL gerenciado no Neon — `DBI` + `RPostgres` + `pool`
- Senhas: `sodium::password_store()` (scrypt), nunca texto puro
- Hospedagem: Posit Connect Cloud (tem variáveis secretas; shinyapps.io não)
- `renv` para travar versões de pacotes
- Testes: `testthat`
- Horários: a conexão devolve tudo no fuso `America/Sao_Paulo` (definido
  em `R/db.R`, coberto por `test-db.R`). Nenhuma tela converte fuso.

**Dois apps Shiny separados, mesmo banco:**

- `urna` — o que os votantes acessam: login, cédula, comprovante.
- `painel` — o que a ANPOCS acessa: mesário e auditoria.

Motivos: quem vota nunca chega perto do código do painel; e o Shiny faz
uma coisa de cada vez por processo — conferir senha é lento de propósito,
e com 119 logins no mesmo minuto um app único deixaria o painel congelado.
As funções compartilhadas moram em `R/`; cada app só tem a sua tela.

Proibido: `shinylive` (roda no navegador, sem servidor, sem banco central —
inviável para eleição). SQLite. Google Sheets como banco primário.

---

## 3. Invariantes

Cada uma vira teste **antes** de virar código. Teste que quebra é sinal de
que a mudança está errada, não de que o teste precisa de ajuste.

1. **Um programa vota no máximo uma vez.** Garantido por chave primária em
   `votantes.programa_id`, não por verificação no código R.
2. **A trava é por programa, não por credencial.** Usada qualquer uma das
   três, as outras duas deixam de funcionar na mesma transação.
3. **`count(votantes) == count(votos)`, sempre.** Qualquer divergência é
   incidente: para a votação.
4. **A tabela `votos` não tem carimbo de tempo nem id sequencial.** Só um
   UUID aleatório e a opção. Nenhuma coluna nova pode violar isso.
5. **Nenhum voto entra com a urna fora do estado `aberta`.** Verificado
   dentro da mesma transação.
6. **A tela só diz "voto depositado" depois do COMMIT.** Nunca antes.
7. **Nenhum estado de voto vive em memória do Shiny.** `reactiveValues`
   guarda navegação de tela, nunca voto pendente. Se o processo cair no
   meio, ou o voto foi commitado ou não existe.
8. **Nenhuma senha em texto puro** no banco, no log, no repositório ou na
   tela.
9. **Em modo `oficial`, nenhuma tela lê conteúdo de voto antes do estado
   `encerrada`.** Não é permissão de usuário: é ausência de caminho de
   código.
10. **A exportação de votos é ordenada pelo UUID aleatório**, nunca por
    ordem de inserção.
11. **No fechamento, a ordem física da tabela `votos` é destruída.** Ver a
    seção 6.

---

## 4. Esquema

```sql
create table programas (
  id           text primary key,          -- identificador curto e estável
  nome_oficial text not null,             -- vai impresso no comprovante
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

-- quem votou. Documento público para a Comissão. NÃO contém o voto.
create table votantes (
  programa_id    text primary key references programas(id),
  credencial_id  bigint not null references credenciais(id),
  votado_em      timestamptz not null default now(),
  comprovante_id text not null unique
);

-- o voto. Nenhuma ligação com votantes. Nenhum tempo. Nenhuma sequência.
create table votos (
  id    uuid primary key,
  opcao text not null                     -- '1','2',... ou 'branco'
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
  membros jsonb not null                  -- [{"nome": "...", "cargo": "..."}]
);

create table log (
  id      bigserial primary key,
  em      timestamptz not null default now(),
  evento  text not null,
  detalhe text                            -- nunca conteúdo de voto
);
```

Fora do esquema, criada uma vez por `dev/01_preparar_banco.R` e **nunca
apagada pelos testes**:

```sql
create table ambiente (
  id        smallint primary key default 1 check (id = 1),
  valor     text not null check (valor in ('dev','producao')),
  criado_em timestamptz not null default now()
);
```

É o carimbo que identifica o banco. Fica dentro do banco, não no computador
de quem se conecta: é o que impede os testes (que apagam tabelas) de rodarem
contra a eleição, mesmo com o `.Renviron` errado.

`login` é o mesmo para as três credenciais do programa; o que muda é a
senha. Isso torna a trava por programa natural e o e-mail de instrução mais
simples.

Senha: 8 caracteres sorteados de um alfabeto **sem caracteres ambíguos**
(sem `0 O o 1 l I`), agrupados em blocos de 4 para digitação em celular.
A verificação tolera minúsculas, hífen e espaços (`normalizar_senha()`).

`carregar_programas()` só roda em banco sem programas: rodar de novo
geraria senhas novas e o banco deixaria de bater com o CSV entregue. As
senhas em texto existem uma única vez, no data.frame que ela devolve.

Todo script que gera senhas confere **antes** que consegue escrever o CSV
(arquivo aberto no Excel trava a escrita). Senão a carga entraria no banco,
a escrita falharia depois, e as senhas ficariam só em hash — perdidas.

---

## 5. A transação do voto

É o coração do sistema. Uma transação, nesta ordem:

```sql
begin;
  select estado from urna where id = 1 for share;   -- impede fechar no meio
  -- abortar se estado <> 'aberta'

  insert into votantes (programa_id, credencial_id, comprovante_id)
  values ($1, $2, $3)
  on conflict (programa_id) do nothing;
  -- 0 linhas afetadas  =>  programa já votou  =>  rollback

  insert into votos (id, opcao)
  values (gen_random_uuid(), $4);
commit;
```

O `INSERT` em `votantes` **é** a trava. Não escreva um `SELECT ... WHERE já
votou` antes dele: entre o SELECT e o INSERT cabem dois votos simultâneos —
e o caso real não é conluio, é a pessoa clicando duas vezes em confirmar.
Deixe o banco recusar.

Em R, `registrar_voto()` chama `force()` nos argumentos antes de abrir a
transação. Sem isso, um argumento que seja ele mesmo uma consulta ao banco
só é calculado no meio da transação e atropela a consulta em curso na mesma
conexão. Os testes cobrem esse caso de propósito.

---

## 6. O fechamento da urna

A transação grava `votantes` e depois `votos`. Logo, a **ordem física** das
linhas de `votos` é a ordem de votação, e `votantes` tem a hora de cada
programa. Quem tiver acesso direto ao banco cruza as duas. Ordenar só na
exportação não resolve: o dado original continua lá.

Por isso, no fechamento — depois de `conferir_integridade()` e antes de
qualquer apuração — a ordem é destruída:

```sql
begin;
  create table votos_novo as
    select id, opcao from votos order by random();
  drop table votos;
  alter table votos_novo rename to votos;
  alter table votos add primary key (id);
commit;
```

Regras: só roda com `urna.estado = 'encerrada'`; `conferir_integridade()`
antes e depois, e `rollback` se não bater; registra no `log`; roda uma vez
só.

Limite que permanece, e que o regulamento deve declarar em vez de esconder:
os backups automáticos do Neon feitos durante a votação ainda contêm a ordem
original, até o fim da janela de retenção.

---

## 7. O que se constrói (e só isso)

**Votante**

1. Login (login do programa + senha), por `autenticar()`:
   - login inexistente e senha errada dão **a mesma resposta**;
   - "já votou" só aparece **depois** da senha certa;
   - confere as credenciais na ordem e para na primeira que bate;
   - o log registra a tentativa, **nunca o texto digitado**;
   - **sem bloqueio de conta**: travar uma credencial numa janela de 30
     minutos é negar o voto a um programa legítimo. Se houver atraso entre
     tentativas, nunca com `Sys.sleep()` — ele congela o app para todos.
2. Cédula: digita o número da chapa → aparecem o nome da chapa e a lista de
   membros com seus cargos → CORRIGE ou CONFIRMA. Sem fotos.
3. "VOTO DEPOSITADO" + download automático do comprovante.

**Comprovante**: nome oficial do programa, data, hora com segundos,
identificador do comprovante, mensagem de voto depositado. **Não contém o
voto.** Ele prova participação, não conteúdo — é isso que impede alguém de
cobrar prova de voto de um coordenador.

Se o download falhar, o voto já está depositado: não trave a tela nisso. A
secretaria da ANPOCS reemite pelo painel.

**Painel do mesário** — app `painel`, separado da urna

- A geração em massa das senhas **não** é um botão do painel: é um script
  rodado uma vez no computador do responsável, para que as 357 senhas em
  texto nunca passem pelo servidor.

- Estado da urna e botões de abrir / encerrar
- Lista de credenciais: verde = apta e não usada, vermelho = inapta,
  azul = em uso neste momento, cinza = já votou
- Lista de comprovantes emitidos (programa, hora, qual credencial), com
  reemissão
- **Revogar uma credencial específica** (ex.: senha mandada ao e-mail
  errado). As três credenciais de um programa valem ao mesmo tempo até ele
  votar; mandar a reserva não desliga a original. Exige uma coluna nova em
  `credenciais` — decidir o formato na etapa 6.
- **Gerar senha nova** para uma credencial de um programa que perdeu as
  três. A senha nova aparece uma vez na tela e não fica guardada.
- **Verificação de integridade ao vivo:** `count(votantes)` vs
  `count(votos)` — só um sinal verde ou vermelho, nunca conteúdo
- **Nunca apuração parcial.** O placar subindo ao lado de quem está votando
  entrega o voto.

**Apuração**

- Zerésima antes da abertura: conta as linhas reais de `votos` (tem que dar
  zero) e imprime o modo da urna
- Boletim de urna no fechamento
- Ata: nº de aptos, nº de votantes, totais por opção, horas de abertura e
  fechamento
- Exportação da tabela de votos já embaralhada

**Não construir**: fotos de candidato, cadastro de candidato em tempo real,
múltiplos cargos, apuração progressiva animada, identidade visual
elaborada, qualquer coisa não listada acima.

---

## 8. Backup

- Primário: Postgres no Neon, com backup automático do provedor.
- Espelho em Google Sheets, **automático, após o COMMIT, e só de
  `votantes` e comprovantes**. Se a escrita no Sheets falhar, registre no
  log e siga: o voto já está seguro. Nunca o contrário.
- **O conteúdo dos votos não é espelhado durante a eleição.** Quem comparar
  duas versões da planilha sabe qual linha entrou entre elas e cruza com a
  hora do comprovante. Embaralhar não resolve isso. A exportação do
  conteúdo acontece uma vez, no fechamento, depois do embaralhamento.

---

## 9. Segredos e dados

- String de conexão do banco e credenciais do Google: variáveis de ambiente
  no Connect Cloud. Nunca no repositório, nunca em `app.R`.
- O CSV com as senhas reais é gerado **uma vez, localmente**, entregue à
  secretaria, e nunca entra no repositório nem em nenhuma sessão de
  trabalho.
- Desenvolvimento sempre contra o banco `urna-dev`, com dados sintéticos.
- Para testar na tela: `dev/03_preparar_urna_dev.R` recria os 119
  programas, o CSV, a urna aberta e duas chapas de exemplo. Os testes
  apagam o banco: rode o `03` depois deles.
- Rodar a urna localmente: `shiny::runApp("urna", launch.browser = TRUE)`.
- Tudo o que apaga tabelas mora em `dev/ferramentas_dev.R`, que o app
  nunca carrega, e passa por `exigir_banco_dev()`.
- `.gitignore`: `.Renviron`, `*.csv`, `credenciais*.json`, `*.sqlite`.

---

## 10. Ordem de construção

Cada etapa com teste antes do código, e commit ao fim de cada uma.

1. ~~Esquema + transação do voto (invariantes 1 a 6)~~ **concluída** —
   33 testes passando
2. ~~Geração de credenciais e carga de 119 programas sintéticos~~
   **concluída** — 92 testes passando no total
3. Login
   - ~~3a. `autenticar()` e testes~~ **concluída** — 119 testes no total
   - ~~3b. Tela de login no app `urna`~~ **concluída** — 121 testes no total
4. Cédula e confirmação
5. Comprovante e reemissão
6. Painel do mesário
7. Zerésima, boletim, ata, fechamento com embaralhamento, exportação
8. Espelho no Sheets
9. Publicação no Connect Cloud
10. Simulação completa com 119 votos e gente de fora testando

---

## 11. Checklist do banco de produção

O banco da eleição é um **projeto Neon separado** do de desenvolvimento,
criado perto da data. Nada abaixo se aplica ao banco de dev — e nada abaixo
pode ser esquecido.

- [ ] Projeto novo no Neon, nome `urna-eleicao`, região São Paulo
- [ ] **Plano pago (Launch) contratado para outubro**, e o *scale to zero*
      desativado nas configurações do compute. No plano gratuito isso é
      impossível: o banco hiberna após 5 minutos de inatividade. Cancelar em
      novembro.
- [ ] Senha do banco diferente da de desenvolvimento
- [ ] `dev/01_preparar_banco.R` rodado com `AMBIENTE <- "producao"`
- [ ] No Connect Cloud, `URNA_AMBIENTE` = `producao`
- [ ] `urna.modo` = `oficial` (a zerésima imprime o modo: confira nela)
- [ ] `urna.estado` = `fechada` até o mesário abrir
- [ ] Tabela `votos` vazia, confirmado pela zerésima
- [ ] Nunca rodar `test_dir()` com o `.Renviron` apontando para este banco

---

## 12. Pendências fora do código

Não são detalhe: sem elas o sistema funciona e a eleição continua frágil.

- **Regulamento da urna** aprovado pela Comissão Eleitoral com base no
  Art. 7º do Regimento (casos omissos). Precisa cobrir: existência do voto
  em branco, critério de desempate, o que acontece se o sistema cair,
  procedimento de reemissão de credencial na hora, e o limite de sigilo
  declarado na seção 6.
- **Plano B em papel, impresso e na sala**, com gatilho objetivo: se a urna
  não voltar em X minutos, anula-se a votação eletrônica e recomeça em
  cédula. Nunca misturar os dois.
- **Distribuição das credenciais pela secretaria da ANPOCS**, com aviso
  prévio por canal oficial de qual é o endereço da urna (senão parece
  phishing — e com razão).
- **Uma segunda pessoa treinada** para operar o painel do mesário no dia 9.
- **Higiene do computador presencial:** o eleitor digita a própria senha, e
  a sessão se encerra sozinha depois do "voto depositado".
