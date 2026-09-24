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
| Cédula | chapas numeradas (1..N) + abstenção |
| Credenciais | 3 por programa; só 1 ativa (a distribuída), 2 reservas inativas |

Duas datas do regimento travam o cronograma:

- **25/09** — prazo de inscrição das chapas. Só depois se sabe quantas
  opções a cédula tem e quais os nomes.
- **28/09** — a ANPOCS entrega a lista oficial de aptos a votar.

Logo: **todo o sistema precisa estar pronto e testado com dados sintéticos
antes de 28/09.** As credenciais reais são geradas depois, e só depois.

### Cronograma

| Data | O quê |
|---|---|
| 23 a 25/09 | Construir tudo, na ordem das camadas de prioridade (ver "Rodadas de teste"). Publicação no Connect Cloud no dia 24, antes do painel. |
| 25/09 | Fecham as inscrições de chapas. Vinicius divide as 60 credenciais de teste entre as pessoas da rodada, com explicação de como votar. |
| 26 e 27/09 | **Rodada 1 de teste**: uma sessão com hora marcada (ou mais), com a urna aberta e encerrada à mão. Algumas pessoas fazem vários votos cada, em sequência, até completar os 60. Testa a experiência (login, cédula, comprovante, celular, redes e navegadores diferentes) e o log. **Não é teste de carga:** 119 votos simultâneos são da etapa 10, por script. |
| 28/09 | Lista oficial. Criar o banco de produção, gerar as senhas reais e publicar a urna de produção, com endereço diferente da urna de teste. |
| 28 a 30/09 | Ajustes da rodada 1. |
| 29/09 a 02/10 | Secretaria distribui as credenciais reais. |
| 01 e 02/10 | **Rodada 2 de teste**, com janela de 30 minutos marcada. Ensaia a assembleia: pico de acessos, mesário abrindo e encerrando pelo painel, apuração na hora. |
| 05 a 09/10 | Semana do Encontro: só correções. |
| 09/10 | Eleição. |

### Rodadas de teste

- Participantes: 60 membros da organização.
- Cédula com chapas de exemplo, não as reais.
- Banco Neon separado: projeto `urna-teste`, nem o de dev nem o da eleição.
- O carimbo de ambiente tem três valores: `dev`, `teste`, `producao` (ver
  seção 4). Os testes automáticos só rodam contra `dev`.

**Operação do banco da rodada** (scripts em `rodada/`, rodados na pasta do
projeto com `Rscript rodada/<script>.R`):

- Os scripts leem `URNA_TESTE_PG_HOST`, `_DB`, `_USER`, `_PASSWORD`,
  `_PORT`, `_SSLMODE` do `.Renviron`, e nunca `URNA_PG_*` (que continuam
  apontando para o dev). Sem elas, param. Todos exigem o carimbo `teste`.
- O app publicado lê só `URNA_PG_*`: no Connect Cloud, elas apontam para o
  urna-teste, com `URNA_AMBIENTE` = `teste`.
- `01_preparar_banco_rodada.R` — **roda uma vez, e quem roda é o
  Vinicius** (as senhas vão para pessoas de verdade). Carimba `teste`,
  cria as tabelas, cadastra as chapas de exemplo, deixa a urna fechada em
  modo teste, carrega 60 participantes (`rodada-01` a `rodada-60`) e gera
  `saida/RODADA_senhas_ATIVAS_enviar_aos_participantes.csv` e
  `saida/RODADA_senhas_RESERVAS_guardar_com_a_mesa.csv`. Recusa banco já
  preparado. Se falhar no meio: apagar e recriar o projeto no Neon.
- `abrir_urna_rodada.R`, `encerrar_urna_rodada.R`,
  `situacao_urna_rodada.R` — enquanto o painel não existe.
- **Mais de uma sessão:** encerrar → `limpar_votos_rodada.R` → abrir.
  A limpeza apaga votos, votantes e log e volta a urna para fechada, mas
  mantém as credenciais: as mesmas 60 senhas valem em todas as sessões e
  rodadas (a não ser que alguma tenha sido trocada por
  `trocar_credencial()`). Antes de apagar, grava em `saida/`, com data no
  nome, o log, a tabela votantes e a tabela votos (ordenada pelo id).
  Exige a urna fora do estado `aberta` e uma confirmação escrita dentro do
  script.

Camadas de prioridade, nesta ordem:

1. **Indispensável:** cédula e confirmação; voto depositado com
   comprovante; banco da rodada com as 60 credenciais; urna publicada.
2. **Transforma a rodada em ensaio:** painel mínimo (abrir e encerrar,
   quem já votou, sinal de integridade); fechamento com embaralhamento;
   apuração com boletim.
3. **Pode esperar:** reemissão de comprovante, trocar para a credencial
   reserva (a função `trocar_credencial()` já existe; falta o botão no
   painel), gerar senha nova, ata completa, zerésima formatada, espelho no Sheets.

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

**Hospedagem.** A urna roda no Connect Cloud. O site da ANPOCS terá só um
botão apontando para ela, o que também ajuda contra phishing: o endereço
divulgado pelo canal oficial é o mesmo do botão. Uma página HTML no site
da ANPOCS não serve, porque a senha do banco ficaria exposta no navegador.

O plano gratuito do Connect Cloud exige repositório público. Antes de
torná-lo público, conferir no histórico do Git (não só no estado atual) que
nenhum arquivo de segredo foi commitado: `.Renviron`, CSV de senhas,
`credenciais*.json`.

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
12. **No máximo uma credencial ativa por programa, e só ela entra e vota.**
    Garantido por índice único parcial em `credenciais (programa_id) where
    ativa`, não por verificação no código R. `autenticar()` e
    `registrar_voto()` só aceitam credencial ativa. A troca passa sempre
    para a próxima reserva; uma credencial que já foi ativa não volta.

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
  ativa       boolean not null default false,
  unique (programa_id, ordem)
);

-- invariante 12: no máximo uma credencial ativa por programa
create unique index credenciais_uma_ativa_por_programa
  on credenciais (programa_id) where ativa;

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
  opcao text not null                     -- '1','2',... ou 'abstencao'
);

create table urna (
  id                smallint primary key default 1 check (id = 1),
  estado            text not null check (estado in ('fechada','aberta','encerrada')),
  modo              text not null check (modo   in ('teste','oficial')),
  permite_abstencao boolean not null default true,
  aberta_em         timestamptz,
  encerrada_em      timestamptz
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

Fora do esquema, criada uma vez por `dev/01_preparar_banco.R` (dev e
produção) ou por `rodada/01_preparar_banco_rodada.R` (teste), e **nunca
apagada pelos testes**:

```sql
create table ambiente (
  id        smallint primary key default 1 check (id = 1),
  valor     text not null check (valor in ('dev','teste','producao')),
  criado_em timestamptz not null default now()
);
```

É o carimbo que identifica o banco. Fica dentro do banco, não no computador
de quem se conecta: é o que impede os testes (que apagam tabelas) de rodarem
contra a eleição, mesmo com o `.Renviron` errado. O valor `teste` é o banco
das rodadas de teste (projeto `urna-teste`); os testes automáticos recusam
tudo que não for `dev`. `exigir_ambiente(con, esperado)` para qualquer
script cujo banco não tenha o carimbo esperado. (O banco urna-dev foi criado
antes do valor `teste` e aceita só `dev` e `producao`; não faz diferença.)

`login` é o mesmo para as três credenciais do programa; o que muda é a
senha. Isso torna a trava por programa natural e o e-mail de instrução mais
simples.

`carregar_programas()` cria a credencial 1 ativa e as reservas 2 e 3
inativas. `trocar_credencial(con, programa_id)`, numa transação, desativa a
ativa e ativa a próxima reserva (1 → 2 → 3). Recusa se o programa já votou
ou se não houver reserva, e registra a troca no `log`, sem senha. Trava as
credenciais do programa com `FOR UPDATE`; `registrar_voto()` trava a
credencial ativa com `FOR SHARE`. Assim, uma troca e um voto simultâneos
nunca se cruzam.

Senha: 8 caracteres sorteados de um alfabeto **sem caracteres ambíguos**
(sem `0 O o 1 l I`), agrupados em blocos de 4 para digitação em celular.
A verificação tolera minúsculas, hífen e espaços (`normalizar_senha()`).

`carregar_programas()` só roda em banco sem programas: rodar de novo
geraria senhas novas e o banco deixaria de bater com os CSV entregues. As
senhas em texto existem uma única vez, no data.frame que ela devolve.

As senhas saem em **dois CSV**, separados por `separar_senhas()`:

- `..._senhas_ATIVAS_enviar_aos_coordenadores.csv`: uma por programa (a
  credencial 1). É o que a secretaria envia aos coordenadores.
- `..._senhas_RESERVAS_guardar_com_a_mesa.csv`: as credenciais 2 e 3. Fica
  guardado com a mesa e só é usado junto com `trocar_credencial()`.

Em dev, os nomes começam com `DEV_`.

Todo script que gera senhas confere **antes** que consegue escrever os dois
CSV (`exigir_escrita()`; arquivo aberto no Excel trava a escrita). Senão a
carga entraria no banco, a escrita falharia depois, e as senhas ficariam só
em hash — perdidas.

---

## 5. A transação do voto

É o coração do sistema. Uma transação, nesta ordem:

```sql
begin;
  select estado from urna where id = 1 for share;   -- impede fechar no meio
  -- abortar se estado <> 'aberta'

  select ... from credenciais where id = $2 and ativa ... for share of c;
  -- abortar se a credencial não for a ativa de um programa apto

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

**Ainda não implementado:** `encerrar_urna()` (`R/urna.R`) só muda o
estado para `encerrada` e confere a integridade. O embaralhamento é da
etapa 7.

Limite que permanece, e que o regulamento deve declarar em vez de esconder:
os backups automáticos do Neon feitos durante a votação ainda contêm a ordem
original, até o fim da janela de retenção.

---

## 7. O que se constrói (e só isso)

**Votante**

1. Login (login do programa + senha), por `autenticar()`:
   - login inexistente e senha errada dão **a mesma resposta**;
   - "já votou" só aparece **depois** da senha certa;
   - confere só a credencial ativa; a senha de uma reserva inativa ou de
     uma credencial trocada recebe a mesma resposta de senha errada;
   - o log registra a tentativa, **nunca o texto digitado**;
   - **sem bloqueio de conta**: travar uma credencial numa janela de 30
     minutos é negar o voto a um programa legítimo. Se houver atraso entre
     tentativas, nunca com `Sys.sleep()` — ele congela o app para todos.
2. Cédula: digita o número da chapa → aparecem o nome da chapa e a lista de
   membros com seus cargos → CORRIGE ou CONFIRMA. Sem fotos. O botão de
   confirmar diz o que confirma: "CONFIRMAR VOTO NA CHAPA N" ou
   "CONFIRMAR ABSTENÇÃO" (`rotulo_confirma()`). O botão
   ABSTENÇÃO (só se `urna.permite_abstencao`) escreve "abstenção" no campo;
   o valor gravado em `votos.opcao` é `abstencao`, sem acento. Não existe
   voto "branco" no sistema.
3. "VOTO DEPOSITADO" + download automático do comprovante.

**Comprovante**: nome oficial do programa, data, hora com segundos,
identificador do comprovante, mensagem de voto depositado. **Não contém o
voto.** Ele prova participação, não conteúdo — é isso que impede alguém de
cobrar prova de voto de um coordenador.

Se o download falhar, o voto já está depositado: não trave a tela nisso. A
secretaria da ANPOCS reemite pelo painel.

Como é feito (`R/comprovante.R`):

- `dados_comprovante(con, programa_id)` lê nome oficial, identificador,
  `votantes.votado_em` (a hora gravada pelo banco, não a do app) e o modo
  da urna. A urna e a reemissão do painel usam essa mesma função.
- `gerar_comprovante_pdf(dados, arquivo)` depende só desses dados e não
  recebe a opção de voto. Usa `grDevices::pdf()`, que vem com o R: sem
  LaTeX, sem navegador, sem pacote extra.
- **Mesmos dados, mesmo arquivo, byte a byte:** a data interna do PDF é
  trocada pela hora do voto. (Só vale na mesma versão do R: o PDF registra
  a versão.)
- A fonte do PDF só tem Latin-1. `texto_latin1()` junta acento separado da
  letra, troca travessão, aspas curvas e reticências por equivalentes
  simples, e o resto que não cabe vira "?". Os acentos do português ficam.
- O R desenha o hífen como sinal de menos; o PDF é corrigido para que o
  identificador copiado do PDF seja `XXXX-XXXX-XXXX` com hífen comum.
- Em modo diferente de `oficial`, toda tela da urna e o comprovante trazem
  a faixa "URNA DE TESTE — votos sem validade". Na dúvida (modo ilegível),
  a faixa aparece.
- A tela de voto depositado baixa o PDF sozinha, tem botão para baixar de
  novo e volta ao login em 60 segundos, com contagem visível. A tela de
  recusa definitiva (já votou, credencial trocada) também. O log registra
  `comprovante_baixado`, com o programa, nunca o voto.

**Painel do mesário** — app `painel`, separado da urna

- A geração em massa das senhas **não** é um botão do painel: é um script
  rodado uma vez no computador do responsável, para que as 357 senhas em
  texto nunca passem pelo servidor.

- Estado da urna e botões de abrir / encerrar (`abrir_urna()`,
  `encerrar_urna()` e `situacao_urna()` já existem em `R/urna.R`)
- Lista de credenciais: verde = apta e não usada, vermelho = inapta,
  azul = em uso neste momento, cinza = já votou
- Lista de comprovantes emitidos (programa, hora, qual credencial), com
  reemissão
- **Trocar para a credencial reserva** (ex.: senha mandada ao e-mail
  errado): botão que chama `trocar_credencial()`. A credencial antiga deixa
  de valer na mesma transação em que a reserva passa a valer. Substitui o
  "revogar credencial" planejado antes.
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
- Os dois CSV com as senhas reais são gerados **uma vez, localmente**. O
  das ativas vai para a secretaria; o das reservas fica com a mesa.
  Nenhum dos dois entra no repositório nem em nenhuma sessão de trabalho.
- Desenvolvimento sempre contra o banco `urna-dev`, com dados sintéticos.
- Para testar na tela: `dev/03_preparar_urna_dev.R` recria os 119
  programas, os dois CSV de senhas, a urna aberta e duas chapas de exemplo. Os testes
  apagam o banco: rode o `03` depois deles.
- Rodar a urna localmente: `shiny::runApp("urna", launch.browser = TRUE)`.
- Tudo o que apaga dados mora em `dev/ferramentas_dev.R`, que o app nunca
  carrega. `zerar_banco_dev()` apaga tabelas e passa por
  `exigir_banco_dev()`. A única outra é `limpar_votos()`: apaga só votos,
  votantes e log, só em banco `teste` (ou `dev`, nos testes), nunca em
  `producao`. **Nenhuma ferramenta apaga todas as tabelas de um banco que
  não seja o de dev.**
- **`URNA_AMBIENTE` contra o carimbo:** o app compara essa variável com o
  carimbo do banco (`conferir_configuracao()`). Se forem diferentes, ou se
  a variável faltar, ninguém entra: a tela diz só "Urna indisponível — mal
  configurada", sem detalhe técnico. No `.Renviron` local, `URNA_AMBIENTE`
  = `dev`; no Connect Cloud, `teste` na rodada e `producao` na eleição.
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
4. ~~Cédula e confirmação~~ **concluída** — 180 testes no total; testada
   na tela. Depois, "branco" trocado por "abstenção" em todo o sistema
5. ~~Comprovante e reemissão~~ **concluída** — 299 testes no total;
   testada na tela. A reemissão usa `dados_comprovante()` +
   `gerar_comprovante_pdf()`; falta o botão no painel (etapa 6)
6. Painel do mesário
7. Zerésima, boletim, ata, fechamento com embaralhamento, exportação
8. Espelho no Sheets — **opcional**: o Neon já faz backup
9. Publicação no Connect Cloud — **antecipada para 24/09**, antes do
   painel (etapa 6), para a rodada 1 de teste
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
- [ ] **Plano Basic do Connect Cloud assinado para outubro.** Cancelar em
      novembro.
- [ ] Depois da rodada 1 de teste, conferir na página de uso da conta do
      Connect Cloud quanto crédito as 48 horas de urna aberta consumiram
- [ ] Senha do banco diferente da de desenvolvimento
- [ ] `dev/01_preparar_banco.R` rodado com `AMBIENTE <- "producao"`
- [ ] No Connect Cloud, `URNA_AMBIENTE` = `producao`. A urna compara com o
      carimbo do banco: se a tela de login mostrar "Urna indisponível — mal
      configurada", a variável ou as `URNA_PG_*` estão erradas. Não abrir a
      votação até a tela de login aparecer.
- [ ] `urna.modo` = `oficial` (a zerésima imprime o modo: confira nela)
- [ ] **A faixa vermelha "URNA DE TESTE — votos sem validade" NÃO aparece**
      na tela de login da urna de produção nem num comprovante de ensaio.
      Se aparecer no dia 9, a urna está em modo `teste` (ou não consegue
      ler o modo): não abrir a votação.
- [ ] `urna.estado` = `fechada` até o mesário abrir
- [ ] Tabela `votos` vazia, confirmado pela zerésima
- [ ] Nunca rodar `test_dir()` com o `.Renviron` apontando para este banco
- [ ] No dia 9, abrir a urna alguns minutos antes de liberar a votação: o
      app dorme quando não tem visitante, e o primeiro acesso demora a
      acordar

---

## 12. Pendências fora do código

Não são detalhe: sem elas o sistema funciona e a eleição continua frágil.

- **Regulamento da urna** aprovado pela Comissão Eleitoral com base no
  Art. 7º do Regimento (casos omissos). Precisa cobrir: a abstenção (a
  Comissão precisa confirmar que ela existe como opção da cédula e se entra
  no total de votos); que o voto confirmado não pode ser alterado nem
  anulado, nem pela mesa, porque o sistema não tem como saber qual voto é
  de qual programa; critério de desempate, o que acontece se o sistema cair,
  procedimento de reemissão de credencial na hora, e o limite de sigilo
  declarado na seção 6.
- **Plano B em papel, impresso e na sala**, com gatilho objetivo: se a urna
  não voltar em X minutos, anula-se a votação eletrônica e recomeça em
  cédula. Nunca misturar os dois.
- **Distribuição das credenciais pela secretaria da ANPOCS**, com aviso
  prévio por canal oficial de qual é o endereço da urna (senão parece
  phishing — e com razão).
- **Recomendar o computador, com ênfase**, nas instruções da rodada de
  teste e nas da eleição. A tela de login já traz a linha discreta
  "Recomendamos votar pelo computador."; as instruções precisam dizer isso
  com destaque.
- **Uma segunda pessoa treinada** para operar o painel do mesário no dia 9.
- **Higiene do computador presencial:** o eleitor digita a própria senha, e
  a sessão se encerra sozinha depois do "voto depositado".
