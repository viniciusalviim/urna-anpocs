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
| Cédula | **chapa única**, "Chapa 1" (número 1, 13 membros) + abstenção |
| Credenciais | 3 por programa, cada uma com um **PIN de 4 números**; só 1 ativa (a distribuída), 2 reservas inativas |
| Votação | **híbrida**: na sala, cada pessoa vota pelo próprio celular (papel com login, PIN e QR code) ou no computador dedicado; online, pelo computador ou pelo celular |

### Decisões da reunião com a organização (25/09)

- Haverá **uma chapa só**. A **abstenção fica**.
- **Hospedagem toda gratuita:** Connect Cloud gratuito e Neon gratuito. O
  repositório fica **público**, e o sistema é apresentado como de código
  aberto.
- Na versão final, as contas do Connect Cloud e do Neon de produção ficam
  num **e-mail criado só para a eleição**.
- **Votação híbrida.** Na sala, cada pessoa vota pelo próprio celular:
  recebe um papel com o login, a senha e um QR code que abre a urna. O
  computador dedicado continua na sala, para quem precisar. Online, votam
  pelo computador ou pelo celular. **O celular é um caminho principal**,
  não uma alternativa.
- **Regra do papel:** a credencial do papel é a **mesma credencial ativa**
  enviada por e-mail (uma ou outra, o voto é um só). O papel é **entregue
  em mãos ao coordenador ou vice identificado**. Os papéis que sobrarem são
  **destruídos**. O QR code tem só o endereço da urna, igual para todos:
  login e PIN são sempre digitados, nunca vão na URL.

### Decisões da versão definitiva (08/10)

- **A senha passa a ser um PIN de 4 números, de 1000 a 9999** (nenhum
  começa com zero, que o Excel apagaria), sorteado sem viés. Continuam 3
  credenciais por programa (1 ativa, 2 reservas), e os 3 PINs de um
  programa são diferentes entre si. A tolerância de completar com zeros à
  esquerda um PIN digitado com menos de 4 números continua, embora os PINs
  gerados não precisem dela.
- **Sem limite de tentativas e sem bloqueio: decisão do Vinicius, tomada
  sabendo do risco medido.** Conferir um PIN leva ~29 ms, e os logins são
  previsíveis (`usp-ppgs`). Quem souber um login consegue testar os 9.000
  PINs em poucos minutos, dentro da janela de 30 minutos (a urna só confere
  PIN com a urna aberta). Foi proposto um limite de 5 erros a cada 2
  minutos por programa; a proposta foi recusada.
- **Entrar e sair sem votar não gasta a credencial:** `autenticar()` só lê
  e registra no log; só `registrar_voto()` grava. A pessoa pode entrar de
  novo quantas vezes precisar até votar (há teste).
- **Lista oficial:** `saida/Lista_Assembleia_Final.xlsx`, 119 linhas, sem
  cabeçalho: UF, universidade, nome do programa, login. Lida por
  `ler_lista_oficial()` (`preparar/preparacao.R`), que:
  - troca espaço não separável por espaço, junta espaços repetidos e apara
    as pontas;
  - guarda o login em minúsculas (quem digitar em maiúsculas entra);
  - aplica só as correções aprovadas (`CORRECOES_LISTA`), e para se o texto
    encontrado não for o esperado:
    - `usp-iri`: "de Pós-Graduação de Pós-Graduação" → "de Pós-Graduação";
    - `ufscar-ppgas`: "Antropologia SociaL" → "Antropologia Social";
    - `unesp-ar-ppgcs`: universidade "UNESP-Araquara" → "UNESP-Araraquara";
    - `ufpa-naea`: "Amazonicos" → "Amazônicos";
    - `puc-ppgcs` e `puc-iri`: universidade "PUC" → "PUC-MG";
      `puc-rs-ppgscp` → "PUC-RS"; `puc-sp-ppgcs` → "PUC-SP";
  - monta o nome oficial "<nome do programa> – <universidade>", que aparece
    no comprovante, no "Votando como" e no papel, e **recusa nomes
    oficiais repetidos**;
  - deduz o tipo: sem "Programa", "Mestrado" ou "Doutorado" no nome, é
    centro. **15 centros, conferidos pelo Vinicius:** `ufba-crh`,
    `ufpa-naea`, `mpeg`, `fundaj-ips`, `fcrb`, `fgv-cpdoc`, `coc`,
    `puc-rio-iri`, `cebrap`, `cedec`, `fbsp`, `ufabc-cecs`, `unicamp-nepo`,
    `unicamp-nep`, `unicamp-pagu`;
  - usa o login como `id` do programa.
- **Login da UFGD:** a ANPOCS confirmou que o certo é UFGD (Universidade
  Federal da Grande Dourados), login `ufgd-ppgs`. A própria planilha já foi
  corrigida (08/10, 10h44; comparada com a versão anterior, foi a única
  mudança). Por isso não há correção para esse login em
  `CORRECOES_LISTA`: ela não acharia o texto antigo e faria a preparação
  parar. O cuidado ficou de outro jeito: `LOGINS_SUBSTITUIDOS` faz a
  preparação **parar se o login antigo `ufgs-ppgs` aparecer** (uma cópia
  antiga da planilha, por exemplo).
- Outros pontos apontados em 08/10 ficaram como estão, porque não foi
  pedida correção: "UNESP-Marília", "USP - EACH" e "FCRB" aparecem duas
  vezes no nome oficial; "Programa Pós-Graduação em Gestão de Políticas
  Públicas" não tem o "de"; "Programa de Política Científica Tecnológica"
  talvez tenha perdido um "e".
- **A chapa oficial vale nos dois sistemas**, teste e final
  (`CHAPA_OFICIAL`, `preparar/chapas.R`); a chapa de exemplo deixou de
  existir. "Chapa 1", número 1, 13 membros, cada um com nome, cargo e
  instituição:
  - Presidência: Angela Maria Alonso (USP)
  - Secretaria Executiva: Marjorie Marona (UNIRIO)
  - Secretaria Executiva Adjunta: Igor José de Renó Machado (UFSCar)
  - Diretoria de Antropologia: Osmundo Santos de Araujo Pinho (UFRB)
  - Diretoria de Ciência Política: Marisa von Bülow (UnB)
  - Diretoria de Sociologia: Alex Niche Teixeira (UFRGS)
  - Diretoria de Publicações: Flavia Mateus Rios (USP)
  - Comitê Acadêmico: Adalberto Moreira Cardoso (UERJ); Patrice Schuch
    (UFRGS); Rachel Meneguello (UNICAMP)
  - Conselho Fiscal: Manoel Leonardo Wanderley Duarte Santos (UFMG);
    Francisco Jatobá de Andrade (UFPE); Antonella Maria Imperatriz
    Tassinari (UFSC)

Duas datas do regimento travam o cronograma:

- **25/09** — prazo de inscrição das chapas. Só depois se sabe quantas
  opções a cédula tem e quais os nomes.
- **28/09** — a ANPOCS entrega a lista oficial de aptos a votar.

Logo: **todo o sistema precisa estar pronto e testado com dados sintéticos
antes de 28/09.** As credenciais reais são geradas depois, e só depois.

### Cronograma

| Data | O quê |
|---|---|
| 23 e 24/09 | Construir, na ordem das camadas de prioridade (ver "Rodadas de teste"). |
| 25/09 | Painel do mesário e **demonstração da urna e do painel para a organização**, no computador do Vinicius. Fecham as inscrições de chapas. Vinicius divide as 60 credenciais de teste entre as pessoas da rodada, com explicação de como votar. |
| 27/09 (dom.) | Ajustes da urna para celular; papel com QR code; preparação da publicação. |
| 28/09 (seg.) | Lista oficial. **Publicação** no Connect Cloud (urna de teste e painel). Criar o banco de produção, gerar as senhas reais e publicar a urna de produção, com endereço diferente da urna de teste. |
| 29 ou 30/09 (ter. ou qua.) | **Rodada 1 de teste, com papel e celular**: uma sessão com hora marcada (ou mais), com a urna aberta e encerrada à mão. Algumas pessoas fazem vários votos cada, em sequência, até completar os 60. Testa a experiência (login, cédula, comprovante, papel com QR code, celulares e computadores, redes e navegadores diferentes) e o log. **Não é teste de carga:** 119 votos simultâneos são da etapa 10, por script. |
| 28 a 30/09 | Ajustes da rodada 1. |
| 29/09 a 02/10 | Secretaria distribui as credenciais reais. |
| 01 e 02/10 | **Rodada 2 de teste**, com janela de 30 minutos marcada. Ensaia a assembleia: pico de acessos, mesário abrindo e encerrando pelo painel, apuração na hora. |
| 05 a 09/10 | Semana do Encontro: só correções. |
| **08/10 (qui.)** | **Versão definitiva:** PIN de 4 números, lista oficial, chapa única. Sistema de teste com a lista real: o banco urna-teste é apagado e recriado no Neon e preparado por `preparar/preparar_banco.R`. |
| 09/10, antes das 19h30 | Sistema final: banco de produção, chapa real e PINs reais, pelo mesmo script (`AMBIENTE <- "producao"`), e checklist da seção 11. |
| 09/10 | Eleição. |

As linhas até 02/10 são o plano original, registrado como histórico.

### Sistema de teste e rodadas de teste

- Desde 08/10, o sistema de teste usa a **lista oficial real** (119
  programas) e a **chapa oficial**, a mesma do sistema final. Antes, as
  rodadas usavam 60 participantes inventados e chapas de exemplo.
- Banco Neon separado: projeto `urna-teste`, nem o de dev nem o da eleição.
- O carimbo de ambiente tem três valores: `dev`, `teste`, `producao` (ver
  seção 4). Os testes automáticos só rodam contra `dev`.

**Preparação, a mesma para o teste e para o sistema final:**
`Rscript preparar/preparar_banco.R`, com `AMBIENTE <- "teste"` ou
`"producao"` no topo. **Quem roda é o Vinicius** (os PINs vão para pessoas
de verdade).

| | teste | producao |
|---|---|---|
| variáveis lidas do `.Renviron` | `URNA_TESTE_PG_*` | `URNA_PROD_PG_*` |
| carimbo do banco | `teste` | `producao` |
| modo da urna | `teste` (faixa de teste) | `oficial` |
| chapa | `CHAPA_OFICIAL` (`preparar/chapas.R`) | a mesma `CHAPA_OFICIAL` |
| PINs ativos | `saida/TESTE_PINS_ATIVOS_enviar_aos_coordenadores.csv` | `saida/PRODUCAO_PINS_ATIVOS_...` |
| PINs reservas | `saida/TESTE_PINS_RESERVAS_guardar_com_a_mesa.csv` | `saida/PRODUCAO_PINS_RESERVAS_...` |

O script:
1. lê e limpa a lista (seção 1);
2. confere o carimbo do banco: vazio ou do mesmo ambiente, senão para;
3. **recusa banco que já tem programas** (rodar de novo geraria PINs novos);
4. confere que consegue escrever os dois CSV antes de gerar os PINs;
5. carimba, cria as tabelas, cadastra a chapa única e deixa a urna
   **fechada**;
6. carrega os 119 programas com 3 PINs cada e grava os dois CSV.

**Recarregar o urna-teste** (ou recomeçar se a preparação falhar no meio):
no painel do Neon, apagar o banco do projeto e criar outro **com o mesmo
nome**. Endereço, usuário e senha do banco continuam iguais, então nem o
`.Renviron` nem o Connect Cloud mudam. Depois, rodar o script.
**Nenhuma ferramenta do projeto apaga tabelas fora do dev.**

**Operação do banco de teste** (scripts em `rodada/`):

- Os scripts leem `URNA_TESTE_PG_HOST`, `_DB`, `_USER`, `_PASSWORD`,
  `_PORT`, `_SSLMODE` do `.Renviron`, e nunca `URNA_PG_*` (que continuam
  apontando para o dev). Sem elas, param. Todos exigem o carimbo `teste`.
- O app publicado lê só `URNA_PG_*`: no Connect Cloud, elas apontam para o
  urna-teste, com `URNA_AMBIENTE` = `teste`.
- `abrir_urna_rodada.R`, `encerrar_urna_rodada.R`,
  `situacao_urna_rodada.R`: alternativa ao painel.
- O antigo `rodada/01_preparar_banco_rodada.R` (60 participantes
  inventados) foi removido em 08/10: rodá-lo por engano no urna-teste
  recriado travaria a preparação com a lista real.
- **Mais de uma sessão:** encerrar → `limpar_votos_rodada.R` → abrir.
  A limpeza apaga votos, votantes e log e volta a urna para fechada, mas
  mantém as credenciais: os mesmos PINs valem em todas as sessões e
  rodadas (a não ser que algum tenha sido trocado por
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
- PINs: guardados só como hash, `sodium::password_store()` (scrypt), nunca
  texto puro
- Leitura da lista oficial (`.xlsx`): pacote `readxl`, **só local** (não vai
  para o Connect Cloud). Papéis: pacote `qrcode`, só local.
- Hospedagem: Posit Connect Cloud, **plano gratuito** (tem variáveis
  secretas; shinyapps.io não). Banco: Neon, **plano gratuito**.
- Pacotes: o Connect Cloud **não usa `renv`**. Ele instala o que está no
  `manifest.json` de cada app (`urna/` e `painel/`), gerado por
  `rsconnect::writeManifest("urna")` e `rsconnect::writeManifest("painel")`.
  Esse comando só procura pacotes dentro da pasta do app; por isso cada app
  tem um `dependencias.R` com um `library()` para cada pacote usado em
  `R/`. O teste `test-publicacao.R` falha se faltar algum no
  `dependencias.R` ou no `manifest.json`. **Mudou pacote: rodar
  `writeManifest` de novo e commitar.**
- Testes: `testthat`
- Horários: a conexão devolve tudo no fuso `America/Sao_Paulo` (definido
  em `R/db.R`, coberto por `test-db.R`). Nenhuma tela converte fuso.

**Dois apps Shiny separados, mesmo banco:**

- `urna` — o que os votantes acessam: login, cédula, comprovante.
- `painel` — o que a ANPOCS acessa: mesário e auditoria.

Motivos: quem vota nunca chega perto do código do painel; e o Shiny faz
uma coisa de cada vez por processo — conferir senha é lento de propósito,
e com 119 logins no mesmo minuto um app único deixaria o painel congelado.
As funções compartilhadas moram em `R/`; cada app só tem a sua tela. Cada
app procura `R/` em `../R` (rodando da pasta dele) ou em `R` (rodando da
raiz do repositório). **A confirmar na primeira publicação:** se o Connect
Cloud leva a pasta `R/` junto com o app. O `manifest.json` lista só os
arquivos da pasta do app. Se a pasta `R/` não for junto, o plano B é copiar
`R/` para dentro de cada app antes de publicar.

Proibido: `shinylive` (roda no navegador, sem servidor, sem banco central —
inviável para eleição). SQLite. Google Sheets como banco primário.

**Hospedagem.** A urna roda no Connect Cloud. O site da ANPOCS terá só um
botão apontando para ela, o que também ajuda contra phishing: o endereço
divulgado pelo canal oficial é o mesmo do botão. Uma página HTML no site
da ANPOCS não serve, porque a senha do banco ficaria exposta no navegador.

O plano gratuito do Connect Cloud exige repositório público. Antes de
torná-lo público, conferir no histórico do Git (não só no estado atual) que
nenhum arquivo de segredo foi commitado: `.Renviron`, CSV de senhas,
`credenciais*.json`, PDFs de papéis ou comprovantes.

**Conferido em 27/09/2026:**
- nenhum desses arquivos jamais foi commitado;
- nenhum commit contém `neon.tech`, `postgres://` ou `PASSWORD=`;
- as únicas senhas no formato `XXXX-XXXX` no histórico são exemplos dos
  testes (`K7PM-3XWQ`, `AAAA-AAAA`, `ZZZZ-9999`).

Refazer a conferência se o repositório receber commits de outra máquina
antes de ficar público.

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
9. **Em qualquer modo, nenhuma tela lê conteúdo de voto antes do estado
   `encerrada`.** Não é permissão de usuário: é ausência de caminho de
   código. Só `embaralhar_votos()` e `apurar()` (`R/apuracao.R`) leem a
   opção, e as duas recusam urna não encerrada. Um teste lê o código de
   `R/`, `urna/` e `painel/` e falha se qualquer outra função citar a
   tabela `votos` (além de `conferir_integridade()`, que só conta, e
   `registrar_voto()`, que só grava).
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

Fora do esquema, criada uma vez por `dev/01_preparar_banco.R` (dev) ou por
`preparar/preparar_banco.R` (teste e produção), e **nunca apagada pelos
testes**:

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

`login` é o mesmo para as três credenciais do programa; o que muda é o
PIN. Isso torna a trava por programa natural e o e-mail de instrução mais
simples. Com a lista oficial, o `id` do programa é o próprio login.

`carregar_programas()` cria a credencial 1 ativa e as reservas 2 e 3
inativas. `trocar_credencial(con, programa_id)`, numa transação, desativa a
ativa e ativa a próxima reserva (1 → 2 → 3). Recusa se o programa já votou
ou se não houver reserva, e registra a troca no `log`, sem senha. Trava as
credenciais do programa com `FOR UPDATE`; `registrar_voto()` trava a
credencial ativa com `FOR SHARE`. Assim, uma troca e um voto simultâneos
nunca se cruzam.

**PIN** (desde 08/10; antes eram 8 caracteres sem ambíguos):
- 4 números, **de 1000 a 9999**: nenhum PIN começa com zero (há teste),
  porque o Excel apagaria o zero;
- sorteados **sem viés** (`gerar_pin()`): dois bytes aleatórios dão 0 a
  65535; de 63000 em diante, sorteia-se de novo; de 0 a 62999, 1000 + o
  resto por 9000 dá cada PIN exatamente 7 vezes. Um teste confere a conta
  para todos os 65536 valores;
- os 3 PINs de um programa são diferentes entre si
  (`gerar_pins_programa()`); entre programas, podem coincidir: quem separa
  é o login;
- a verificação tolera espaços e hífen, e completa com zeros à esquerda um
  PIN digitado com menos de 4 números (`normalizar_senha()`): "427" vale
  "0427". Os PINs gerados não precisam disso; a tolerância fica por
  segurança.

`carregar_programas()` só roda em banco sem programas: rodar de novo
geraria PINs novos e o banco deixaria de bater com os CSV entregues. Os
PINs em texto existem uma única vez, no data.frame que ela devolve.

Os PINs saem em **dois CSV**, separados por `separar_senhas()` (a coluna
se chama `senha` e guarda o PIN, como texto):

- `<AMBIENTE>_PINS_ATIVOS_enviar_aos_coordenadores.csv`: um por programa
  (a credencial 1). É o que a secretaria envia aos coordenadores.
- `<AMBIENTE>_PINS_RESERVAS_guardar_com_a_mesa.csv`: as credenciais 2 e 3.
  Fica guardado com a mesa e só é usado junto com `trocar_credencial()`.

`<AMBIENTE>` é `TESTE` ou `PRODUCAO`. O dev (`dev/02`) ainda usa
`DEV_senhas_...`.

Os CSV são UTF-8 separados por vírgula. **Aberto com dois cliques no Excel
em português, ele pode mostrar os acentos errados ou juntar tudo numa
coluna.** Para abrir certo: Excel → Dados → De Texto/CSV → origem 65001
(UTF-8), delimitador vírgula. Como nenhum PIN começa com zero, o Excel não
tem zero para apagar.

Todo script que gera PINs confere **antes** que consegue escrever os dois
CSV (`exigir_escrita()`; arquivo aberto no Excel trava a escrita). Senão a
carga entraria no banco, a escrita falharia depois, e os PINs ficariam só
em hash — perdidos.

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

Implementado em `embaralhar_votos()` (`R/apuracao.R`), chamado pelo botão
"Embaralhar e apurar" do painel. "Uma vez só" é conferido pelo evento
`votos_embaralhados` no log (na rodada de teste, `limpar_votos()` apaga o
log e libera a sessão seguinte). O `create table as` não copia o `not null`
da opção: a função o recoloca, e um teste confere a estrutura de `votos`
depois. `apurar()` só roda depois do embaralhamento. `encerrar_urna()` só
muda o estado; ele não embaralha.

Limite que permanece, e que o regulamento deve declarar em vez de esconder:
os backups automáticos do Neon feitos durante a votação ainda contêm a ordem
original, até o fim da janela de retenção.

---

## 7. O que se constrói (e só isso)

**Votante**

0. **Celular é caminho principal** (`R/tela.R`):
   - letra de 16 px nos campos, para o iPhone não dar zoom;
   - botões com pelo menos 48 px de altura;
   - texto longo quebra linha, sem rolagem lateral (conferido a 375 px de
     largura);
   - login e senha sem maiúscula automática, sem corretor, sem sugestão;
   - **botão de olho** para mostrar ou esconder a senha;
   - teclado numérico no campo do número;
   - no iPhone, aviso de como salvar o comprovante se ele abrir numa aba.
   
   **Nada é lido da URL:** um teste falha se a urna usar
   `parseQueryString`, `url_search` ou `clientData$url`.
1. Login (login do programa + senha), por `autenticar()`:
   - login inexistente e senha errada dão **a mesma resposta**;
   - "já votou" só aparece **depois** da senha certa;
   - confere só a credencial ativa; a senha de uma reserva inativa ou de
     uma credencial trocada recebe a mesma resposta de senha errada;
   - o log registra a tentativa, **nunca o texto digitado**;
   - **sem bloqueio de conta**: travar uma credencial numa janela de 30
     minutos é negar o voto a um programa legítimo. Se houver atraso entre
     tentativas, nunca com `Sys.sleep()` — ele congela o app para todos.
     Desde 08/10, também **sem limite de tentativas**, por decisão do
     Vinicius, sabendo do risco de adivinhação do PIN (seção 1);
   - o campo do PIN abre o teclado numérico; a resposta de erro é "Login
     ou PIN incorretos.";
   - entrar e sair sem votar não gasta a credencial.
2. Cédula: digita o número da chapa → aparecem o nome da chapa e a lista de
   membros com seus cargos → CORRIGE ou CONFIRMA. Sem fotos. O botão de
   confirmar diz o que confirma: "CONFIRMAR VOTO NA CHAPA N" ou
   "CONFIRMAR ABSTENÇÃO" (`rotulo_confirma()`). O botão
   ABSTENÇÃO (só se `urna.permite_abstencao`) escreve "abstenção" no campo;
   o valor gravado em `votos.opcao` é `abstencao`, sem acento. Não existe
   voto "branco" no sistema.
   - Os membros aparecem **agrupados pelo cargo**, na ordem da chapa, cada
     um como "Nome (Instituição)" (`agrupar_membros()`, `cartao_opcao()`).
   - **O CONFIRMA fica fixo na parte de baixo da tela** enquanto a lista de
     membros está à vista. Com 13 nomes, ele sairia da tela do celular. Por
     isso a página usa `overflow-x: clip`, e não `hidden`, que impediria o
     botão de ficar fixo.
   - Conferido em 08/10 a 375 px de largura, numa prévia sem banco: sem
     rolagem lateral, nomes com 16 px, botão sempre visível e sem cobrir o
     último nome.
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

**Painel do mesário** — app `painel/app.R`, separado da urna

- A geração em massa dos PINs **não** é um botão do painel: é um script
  rodado uma vez no computador do responsável, para que os 357 PINs em
  texto nunca passem pelo servidor.

- **Acesso:** confere `URNA_AMBIENTE` contra o carimbo, como a urna, e
  pede a senha do mesário. Só o hash fica guardado, em `URNA_MESARIO_HASH`
  (em hexadecimal: o hash do sodium tem `$`, que o `.Renviron` poderia
  interpretar). Gerar com `source("dev/gerar_hash_mesario.R")` no RStudio.
  Sem a variável, ninguém entra. O log registra `painel_login_ok` e
  `painel_login_falhou`, nunca o que foi digitado.
- Estado da urna e botão de abrir / encerrar, com janela de confirmação
  (`abrir_urna()`, `encerrar_urna()`, `situacao_urna()` em `R/urna.R`)
- Lista de programas (`listar_programas()`, `R/painel.R`), atualizada a
  cada 5 segundos: login, nome, credencial ativa, situação e hora do voto.
  Verde = apto e não votou, azul = entrou na urna (login aceito depois da
  abertura) e não votou, cinza = já votou, vermelho = inapto
- **Trocar para a credencial reserva** (ex.: senha mandada ao e-mail
  errado): aba que chama `trocar_credencial()`, com confirmação. A
  credencial antiga deixa de valer na mesma transação em que a reserva
  passa a valer.
- **Reemitir comprovante:** aba que baixa o PDF de um programa que já
  votou, por `dados_comprovante()` + `gerar_comprovante_pdf()`. Log
  `comprovante_reemitido`.
- **Gerar senha nova** para uma credencial de um programa que perdeu as
  três. A senha nova aparece uma vez na tela e não fica guardada.
  **Não construído.**
- **Verificação de integridade ao vivo:** `count(votantes)` vs
  `count(votos)` — só um sinal verde ou vermelho, e "X de Y aptos já
  votaram". Nunca conteúdo.
- **Nunca apuração parcial.** O placar subindo ao lado de quem está votando
  entrega o voto. Com a urna encerrada, o botão "Embaralhar e apurar"
  mostra a integridade antes e depois do embaralhamento e a apuração: total
  por chapa (inclusive zero), abstenções, votantes e aptos.

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
- Os dois CSV com os PINs reais (e os do sistema de teste, que usa a lista
  real) são gerados **uma vez, localmente**, por
  `preparar/preparar_banco.R`. O dos ativos vai para a secretaria; o das
  reservas fica com a mesa. Nenhum dos dois entra no repositório nem em
  nenhuma sessão de trabalho.
- Desenvolvimento sempre contra o banco `urna-dev`, com dados sintéticos.
- Para testar na tela: `dev/03_preparar_urna_dev.R` recria os 119
  programas sintéticos, os dois CSV de PINs, a urna (fechada por padrão;
  `ESTADO_URNA` no topo) e a chapa oficial. Os testes apagam o
  banco: rode o `03` depois deles.
- **Muitos votos ao mesmo tempo:** `Rscript dev/simular_carga.R`, só no dev
  (apaga o banco de dev; depois, rode o `03`). Abre 20 processos que entram
  e votam ao mesmo tempo, pelas mesmas funções da urna, com 20 tentativas
  de voto duplo de propósito. **Resultado em 08/10: aprovado.**
  - 119 votos aceitos; as 20 tentativas duplas recusadas (3 delas pela
    trava do banco, porque chegaram juntas até a gravação; 17 já na
    entrada, como "já votou");
  - votantes = votos;
  - entrada: mediana 0,18 s, máximo 0,78 s; voto: mediana 0,20 s, máximo
    0,59 s.
  
  Mede o banco e a transação, **não** o servidor do Connect Cloud com
  navegadores de verdade.
- Rodar a urna localmente: `shiny::runApp("urna", launch.browser = TRUE)`;
  o painel: `shiny::runApp("painel", launch.browser = TRUE)`.
- **Urna e painel juntos** (demonstração): dois cliques em
  `dev/demonstracao.bat`. Abre duas janelas pretas (urna na porta 8001,
  painel na 8002) e as duas abas do navegador. Para parar, fechar as
  janelas pretas. Para a urna começar fechada, `ESTADO_URNA <- "fechada"`
  no topo do `dev/03` antes de rodá-lo.
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
- **Papéis para imprimir:** `Rscript dev/gerar_papeis.R`, só no
  computador do responsável.
  - No topo do script: `ENDERECO_URNA` (https, sem `?` nem `#`),
    `ARQUIVO_ATIVAS` e `ARQUIVO_PDF`.
  - Gera uma página A4 por programa, com nome, login, PIN e um QR code só
    com o endereço da urna.
  - Por padrão, lê `saida/TESTE_PINS_ATIVOS_enviar_aos_coordenadores.csv`.
    Os papéis de teste (`TESTE_`, `RODADA_`, `DEV_`) trazem a faixa
    "CREDENCIAL DE TESTE / este PIN NÃO vale na eleição": o mesmo login
    terá outro PIN no sistema final.
  - Recusa o arquivo de reservas.
  - Arquivos `RODADA_` ou `DEV_` saem com a faixa "CREDENCIAL DE TESTE".
  - O PDF contém senhas: apagar depois de imprimir.
  - Precisa do pacote `qrcode`, só local; ele não vai para o Connect Cloud.
- `.gitignore`: `.Renviron`, `*.csv`, `*.pdf`, `saida/`,
  `credenciais*.json`, `*.sqlite`.

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
6. ~~Painel do mesário~~ **concluída** — 530 testes no total; testado no
   navegador (abrir, votar, lista, troca de credencial, encerrar, apurar,
   reemitir). Falta só "gerar senha nova"
7. Zerésima, boletim, ata, fechamento com embaralhamento, exportação
   - ~~fechamento com embaralhamento e apuração~~ **feitos** junto com a
     etapa 6 (`R/apuracao.R`)
   - faltam: zerésima, boletim, ata, exportação
8. Espelho no Sheets — **opcional**: o Neon já faz backup
9. Publicação no Connect Cloud — **28/09**, para a rodada 1 de teste
   - ~~preparação~~ **feita em 27/09**:
     - `manifest.json` e `dependencias.R` da urna e do painel;
     - conferência do histórico do Git;
     - `saida/` e `*.pdf` no `.gitignore`.
   - falta: publicar e confirmar que a pasta `R/` vai junto (seção 2)
10. Simulação completa com 119 votos e gente de fora testando
    - ~~119 votos simultâneos por script~~ **aprovado em 08/10**
      (`dev/simular_carga.R`, seção 9)
    - falta: gente de fora testando o sistema de teste com a lista real

**Versão definitiva (08/10):** PIN de 4 números, lista oficial com limpeza
e correções, chapa única, script único de preparação
(`preparar/preparar_banco.R`) e simulação de carga. Depois, PIN de 1000 a
9999, sem zero na frente; login da UFGD; chapa oficial com 13 membros nos
dois sistemas. 1222 verificações nos testes, todas passando (incluindo as
que leem a lista oficial).

---

## 11. Checklist do banco de produção

O banco da eleição é um **projeto Neon separado** do de desenvolvimento,
criado perto da data. Nada abaixo se aplica ao banco de dev — e nada abaixo
pode ser esquecido.

- [ ] **Contas do Neon e do Connect Cloud de produção no e-mail criado só
      para a eleição**, não no e-mail pessoal
- [ ] Projeto novo no Neon (plano gratuito), nome `urna-eleicao`, região
      São Paulo
- [ ] **O Neon gratuito dorme depois de 5 minutos sem uso**, e a primeira
      conexão depois disso demora alguns segundos. No dia 9, abrir o painel
      bem antes das 19h30 e deixá-lo aberto: ele consulta o banco a cada 5
      segundos, e o banco não dorme
- [ ] **Limites do Connect Cloud gratuito** (memória, horas de uso, muitas
      pessoas entrando ao mesmo tempo): medir na rodada 1 e no teste de
      carga da etapa 10, antes de confiar neles no dia 9
- [ ] Repositório público: refazer a conferência do histórico do Git
      (seção 2) antes de tornar público
- [ ] Senha do banco diferente da de desenvolvimento
- [ ] **Senha do mesário da eleição diferente** da usada na demonstração e
      na rodada de teste, e conhecida só pelo Vinicius e pela segunda
      pessoa treinada. Gerar o hash novo com `dev/gerar_hash_mesario.R` e
      pôr em `URNA_MESARIO_HASH` onde o painel de produção roda
- [x] `CHAPA_OFICIAL` preenchida em `preparar/chapas.R` (08/10: "Chapa 1",
      13 membros com cargo e instituição)
- [ ] `CHAPA_OFICIAL` conferida com a Comissão, nome por nome, na tela da
      cédula do sistema de teste
- [ ] `URNA_PROD_PG_*` no `.Renviron` apontando para o banco da eleição
- [x] Login da UFGD confirmado com a ANPOCS (08/10): `ufgd-ppgs`, já
      corrigido na planilha
- [ ] `preparar/preparar_banco.R` rodado **uma vez** com
      `AMBIENTE <- "producao"`. Ele carimba `producao`, deixa a urna
      fechada em modo `oficial` e gera
      `saida/PRODUCAO_PINS_ATIVOS_enviar_aos_coordenadores.csv` (para a
      secretaria) e `..._RESERVAS_guardar_com_a_mesa.csv` (para a mesa)
- [ ] Papéis da eleição gerados com `dev/gerar_papeis.R` apontando para o
      arquivo `PRODUCAO_...` e para o endereço da urna de produção: **sem**
      a faixa de teste
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
- **Papéis com a credencial**, impressos por `dev/gerar_papeis.R`:
  - antes de imprimir tudo, conferir um papel lendo o QR code com um
    celular;
  - entregar cada papel em mãos ao coordenador ou vice identificado;
  - destruir os que sobrarem;
  - apagar o PDF.
- **Instruções da rodada e da eleição:** o celular é um caminho principal.
  Explicar o QR code do papel, o PIN de 4 números e o botão de olho. No
  iPhone, o comprovante pode abrir numa aba: a tela explica como salvar.
- **PIN de teste × PIN da eleição:** o mesmo login terá um PIN no sistema
  de teste e outro no sistema final. Avisar os coordenadores, por escrito,
  que o PIN de teste não vale no dia 9.
- **Secretaria e o CSV:** abrir pelo Excel → Dados → De Texto/CSV (UTF-8,
  vírgula), para não perder os acentos (seção 4).
- **Uma segunda pessoa treinada** para operar o painel do mesário no dia 9.
- **Higiene do computador presencial:** o eleitor digita a própria senha, e
  a sessão se encerra sozinha depois do "voto depositado".
