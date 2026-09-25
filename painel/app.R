# Urna ANPOCS 2026 — painel do mesário
#
# App separado da urna (seção 2 do CLAUDE.md), mesmo banco.
#
# Para rodar: shiny::runApp("painel", launch.browser = TRUE)
#
# Invariante 9: antes do encerramento, nenhuma tela daqui lê conteúdo de
# voto. O painel só conta votantes e votos; o conteúdo só é lido por
# embaralhar_votos() e apurar() (R/apuracao.R), que recusam urna não
# encerrada.

library(shiny)
library(bslib)

# Funções compartilhadas com a urna (uma pasta acima).
for (f in sort(list.files("../R", pattern = "\\.R$", full.names = TRUE))) {
  source(f)
}

pool <- conectar_pool()
onStop(function() pool::poolClose(pool))

SEGUNDOS_ATUALIZACAO <- 5

MOTIVOS_TROCA <- c(
  programa_inexistente = "Programa não encontrado.",
  ja_votou             = "Este programa já votou: a credencial não pode mais ser trocada.",
  sem_credencial_ativa = "Este programa não tem credencial ativa.",
  sem_reserva          = "Este programa já usou as duas reservas.",
  erro_interno         = "Erro ao falar com o banco. Nada mudou; tente de novo."
)

texto_motivo <- function(tabela, motivo) {
  m <- tabela[motivo]
  if (is.na(m)) paste("Recusado:", motivo) else unname(m)
}

hora <- function(t) {
  if (length(t) == 0 || is.na(t)) "" else format(t, "%H:%M:%S")
}

ui <- page_fluid(
  theme = bs_theme(version = 5),
  title = "Painel do mesário — Urna ANPOCS 2026",

  # A atualização a cada poucos segundos não pode fazer a tela piscar.
  tags$style(HTML(".recalculating { opacity: 1 !important; }")),

  tags$script(HTML(
    "document.addEventListener('keydown', function(e) {
       if (e.key === 'Enter') {
         var b = document.getElementById('entrar_painel');
         if (b) b.click();
       }
     });"
  )),

  uiOutput("faixa"),

  tags$div(
    style = "max-width: 1100px; margin: 1.5rem auto;",
    tags$h3("Painel do mesário"),
    tags$p(class = "text-muted",
           "Eleição ANPOCS 2026 — Conselho Diretivo e Conselho Fiscal"),
    tags$hr(),
    uiOutput("tela")
  )
)

server <- function(input, output, session) {

  configurada <- tryCatch(conferir_configuracao(pool), error = function(e) FALSE)
  com_senha   <- mesario_configurado()

  autenticado <- reactiveVal(FALSE)
  aviso       <- reactiveVal(NULL)
  resultado   <- reactiveVal(NULL)   # embaralhamento + apuração, só após encerrada
  atualizar   <- reactiveVal(0)      # força releitura depois de uma ação
  relogio     <- reactiveTimer(SEGUNDOS_ATUALIZACAO * 1000)

  refazer <- function() atualizar(isolate(atualizar()) + 1)

  com_conexao <- function(f, ...) {
    tryCatch({
      con <- pool::localCheckout(pool)
      f(con, ...)
    }, error = function(e) list(ok = FALSE, motivo = "erro_interno"))
  }

  # ---- entrada -------------------------------------------------------------

  observeEvent(input$entrar_painel, {
    if (!configurada || !com_senha) return()
    ok <- verificar_senha_mesario(input$senha_mesario)
    try(registrar_log(pool, if (ok) "painel_login_ok" else "painel_login_falhou"),
        silent = TRUE)
    if (ok) {
      aviso(NULL)
      autenticado(TRUE)
    } else {
      aviso("Senha incorreta.")
    }
  })

  observeEvent(input$sair_painel, {
    autenticado(FALSE)
    resultado(NULL)
  })

  # ---- leitura periódica (só contagens) -------------------------------------

  dados <- reactive({
    req(autenticado())
    relogio()
    atualizar()
    tryCatch(list(
      sit  = situacao_urna(pool),
      cont = contagem_votacao(pool),
      prog = listar_programas(pool),
      emb  = votos_embaralhados(pool),
      em   = Sys.time()
    ), error = function(e) NULL)
  })

  # Se a urna sair de 'encerrada' (limpeza entre sessões da rodada), a
  # apuração mostrada deixa de valer.
  observe({
    d <- dados()
    if (!is.null(d) && !identical(d$sit$estado, "encerrada") &&
        !is.null(isolate(resultado()))) {
      resultado(NULL)
    }
  })

  # ---- faixa de teste --------------------------------------------------------

  output$faixa <- renderUI({
    atualizar()
    modo <- tryCatch(ler_modo_urna(pool), error = function(e) NA_character_)
    if (e_modo_teste(modo)) {
      tags$div(
        style = paste("background: #c62828; color: white; font-weight: bold;",
                      "text-align: center; padding: 0.6rem; font-size: 1.15rem;"),
        FAIXA_TESTE
      )
    }
  })

  # ---- abrir e encerrar ------------------------------------------------------

  observeEvent(input$abrir, {
    showModal(modalDialog(
      title = "Abrir a urna?",
      "A partir de agora, os votantes podem votar.",
      footer = tagList(modalButton("Cancelar"),
                       actionButton("abrir_sim", "Sim, abrir a urna",
                                    class = "btn-success"))
    ))
  })

  observeEvent(input$abrir_sim, {
    removeModal()
    r <- com_conexao(abrir_urna)
    if (isTRUE(r$ok)) showNotification("Urna aberta.", type = "message")
    else showNotification(explicar_motivo_urna(r$motivo), type = "error", duration = NULL)
    refazer()
  })

  observeEvent(input$encerrar, {
    showModal(modalDialog(
      title = "Encerrar a urna?",
      "Ninguém mais poderá votar. A urna não reabre.",
      footer = tagList(modalButton("Cancelar"),
                       actionButton("encerrar_sim", "Sim, encerrar a urna",
                                    class = "btn-danger"))
    ))
  })

  observeEvent(input$encerrar_sim, {
    removeModal()
    r <- com_conexao(encerrar_urna)
    if (isTRUE(r$ok)) {
      if (isTRUE(r$integridade$ok)) {
        showNotification("Urna encerrada.", type = "message")
      } else {
        showNotification("Urna encerrada. INCIDENTE: votantes e votos não batem.",
                         type = "error", duration = NULL)
      }
    } else {
      showNotification(explicar_motivo_urna(r$motivo), type = "error", duration = NULL)
    }
    refazer()
  })

  # ---- embaralhar e apurar ---------------------------------------------------

  observeEvent(input$apurar, {
    ja <- isTRUE(isolate(dados())$emb)
    showModal(modalDialog(
      title = if (ja) "Mostrar a apuração?" else "Embaralhar e apurar?",
      if (ja) "Os votos já foram embaralhados. A apuração vai ser mostrada."
      else paste("A ordem da tabela de votos vai ser destruída (isso só",
                 "acontece uma vez) e, em seguida, os votos vão ser contados."),
      footer = tagList(modalButton("Cancelar"),
                       actionButton("apurar_sim", "Sim", class = "btn-primary"))
    ))
  })

  observeEvent(input$apurar_sim, {
    removeModal()
    r <- com_conexao(function(con) {
      e <- NULL
      if (!votos_embaralhados(con)) {
        e <- embaralhar_votos(con)
        if (!isTRUE(e$ok)) return(list(ok = FALSE, motivo = e$motivo))
      }
      a <- apurar(con)
      if (!isTRUE(a$ok)) return(list(ok = FALSE, motivo = a$motivo))
      list(ok = TRUE, embaralhamento = e, apuracao = a)
    })
    if (isTRUE(r$ok)) {
      resultado(r)
    } else {
      showNotification(texto_motivo(MOTIVOS_APURACAO, r$motivo),
                       type = "error", duration = NULL)
    }
    refazer()
  })

  # ---- trocar credencial -----------------------------------------------------

  observeEvent(input$trocar, {
    req(input$prog_trocar)
    p <- isolate(dados())$prog
    linha <- p[p$programa_id == input$prog_trocar, ]
    req(nrow(linha) == 1)
    showModal(modalDialog(
      title = "Trocar para a credencial reserva?",
      tags$p(tags$strong(linha$login), " — ", linha$nome_oficial),
      tags$p("A senha da credencial ", linha$credencial_ativa,
             " deixa de valer imediatamente. Passa a valer a reserva seguinte."),
      footer = tagList(modalButton("Cancelar"),
                       actionButton("trocar_sim", "Sim, trocar", class = "btn-warning"))
    ))
  })

  observeEvent(input$trocar_sim, {
    removeModal()
    r <- com_conexao(trocar_credencial, input$prog_trocar)
    if (isTRUE(r$ok)) {
      showNotification(paste0("Agora vale a credencial ", r$ordem,
                              ". Entregue a senha de ordem ", r$ordem,
                              " do arquivo de reservas."),
                       type = "message", duration = NULL)
    } else {
      showNotification(texto_motivo(MOTIVOS_TROCA, r$motivo), type = "error",
                       duration = NULL)
    }
    refazer()
  })

  # ---- reemitir comprovante --------------------------------------------------

  output$reemitir <- downloadHandler(
    filename = function() {
      d <- dados_comprovante(pool, input$prog_comprovante)
      if (is.null(d)) "comprovante.pdf"
      else paste0("comprovante_", d$comprovante_id, ".pdf")
    },
    content = function(file) {
      d <- dados_comprovante(pool, input$prog_comprovante)
      if (is.null(d)) stop("Este programa ainda não votou.")
      gerar_comprovante_pdf(d, file)
      registrar_log(pool, "comprovante_reemitido", input$prog_comprovante)
    },
    contentType = "application/pdf"
  )

  # ---- partes da tela --------------------------------------------------------

  output$estado <- renderUI({
    d <- dados()
    if (is.null(d)) {
      return(tags$div(class = "alert alert-danger",
                      "Sem conexão com o banco. Tentando de novo..."))
    }
    s <- d$sit
    cor <- switch(s$estado, fechada = "secondary", aberta = "success",
                  encerrada = "dark", "danger")
    botao <- switch(s$estado,
      fechada   = actionButton("abrir", "ABRIR A URNA", class = "btn-success btn-lg"),
      aberta    = actionButton("encerrar", "ENCERRAR A URNA", class = "btn-danger btn-lg"),
      encerrada = actionButton("apurar",
                               if (isTRUE(d$emb)) "MOSTRAR A APURAÇÃO"
                               else "EMBARALHAR E APURAR",
                               class = "btn-primary btn-lg"),
      NULL)

    tags$div(
      class = "d-flex flex-wrap align-items-center justify-content-between gap-3",
      tags$div(
        tags$h4(class = "mb-1", "Urna: ",
                tags$span(class = paste0("badge bg-", cor), toupper(s$estado))),
        tags$div(class = "text-muted small",
                 "Modo: ", s$modo,
                 " · Aberta em: ", if (is.na(s$aberta_em)) "—"
                                   else format(s$aberta_em, "%d/%m/%Y %H:%M:%S"),
                 " · Encerrada em: ", if (is.na(s$encerrada_em)) "—"
                                      else format(s$encerrada_em, "%d/%m/%Y %H:%M:%S"))
      ),
      botao
    )
  })

  output$integridade <- renderUI({
    d <- dados()
    req(d)
    c <- d$cont
    tags$div(
      class = "d-flex flex-wrap gap-3 my-3",
      tags$div(
        class = paste("p-3 rounded text-white",
                      if (isTRUE(c$integridade_ok)) "bg-success" else "bg-danger"),
        tags$strong(if (isTRUE(c$integridade_ok)) "INTEGRIDADE OK"
                    else "INCIDENTE: VOTANTES ≠ VOTOS"),
        tags$div(class = "small", "votantes = votos")
      ),
      tags$div(
        class = "p-3 rounded border",
        tags$strong(style = "font-size: 1.4rem;", c$votantes, " de ", c$aptos),
        tags$div(class = "small text-muted", "aptos já votaram")
      ),
      tags$div(class = "small text-muted align-self-end",
               "Atualizado às ", format(d$em, "%H:%M:%S"),
               " (a cada ", SEGUNDOS_ATUALIZACAO, " s)")
    )
  })

  output$apuracao <- renderUI({
    r <- resultado()
    if (is.null(r)) return(NULL)
    a <- r$apuracao
    e <- r$embaralhamento
    t <- a$tabela

    tags$div(
      class = "card my-3",
      tags$div(class = "card-header", tags$strong("Apuração")),
      tags$div(
        class = "card-body",
        if (!is.null(e)) {
          tags$p(class = "small", paste0(
                 "Embaralhamento feito agora. Integridade antes: ",
                 if (isTRUE(e$antes$ok)) "ok" else "DIVERGENTE",
                 " (", e$antes$votos, " votos) · depois: ",
                 if (isTRUE(e$depois$ok)) "ok" else "DIVERGENTE",
                 " (", e$depois$votos, " votos)."))
        } else {
          tags$p(class = "small text-muted", "Votos embaralhados anteriormente.")
        },
        tags$table(
          class = "table table-sm",
          tags$thead(tags$tr(tags$th("Opção"), tags$th("Nome"),
                             tags$th(class = "text-end", "Votos"))),
          tags$tbody(lapply(seq_len(nrow(t)), function(i) {
            tags$tr(tags$td(if (t$opcao[i] == "abstencao") "—" else t$opcao[i]),
                    tags$td(t$nome[i]),
                    tags$td(class = "text-end", tags$strong(t$votos[i])))
          })),
          tags$tfoot(tags$tr(tags$th(""), tags$th("Total de votos"),
                             tags$th(class = "text-end", a$total_votos)))
        ),
        tags$p(class = "mb-0",
               "Votantes: ", tags$strong(a$votantes),
               " · Aptos: ", tags$strong(a$aptos),
               " · Integridade: ", if (isTRUE(a$integridade_ok)) "ok" else "DIVERGENTE")
      )
    )
  })

  output$programas <- renderUI({
    d <- dados()
    req(d)
    p <- d$prog
    classe <- ifelse(p$votou, "table-secondary",
              ifelse(p$entrou_sem_votar, "table-primary",
              ifelse(!p$apto, "table-danger", "table-success")))
    situacao <- ifelse(p$votou, "votou",
                ifelse(p$entrou_sem_votar, "entrou, não votou",
                ifelse(!p$apto, "inapto", "apto, não votou")))

    tagList(
      tags$p(class = "small",
             tags$span(class = "badge text-bg-success", "apto, não votou"), " ",
             tags$span(class = "badge text-bg-primary", "entrou, não votou"), " ",
             tags$span(class = "badge text-bg-secondary", "votou"), " ",
             tags$span(class = "badge text-bg-danger", "inapto")),
      tags$table(
        class = "table table-sm",
        tags$thead(tags$tr(
          tags$th("Login"), tags$th("Programa"), tags$th("Credencial ativa"),
          tags$th("Situação"), tags$th("Hora do voto"))),
        tags$tbody(lapply(seq_len(nrow(p)), function(i) {
          tags$tr(class = classe[i],
                  tags$td(p$login[i]), tags$td(p$nome_oficial[i]),
                  tags$td(if (is.na(p$credencial_ativa[i])) "—" else p$credencial_ativa[i]),
                  tags$td(situacao[i]),
                  tags$td(hora(p$votado_em[i])))
        }))
      )
    )
  })

  # ---- telas -----------------------------------------------------------------

  output$tela <- renderUI({
    if (!configurada) {
      return(tags$div(class = "alert alert-danger",
        tags$h5("Painel indisponível"),
        tags$p(class = "mb-0", "Este painel está mal configurado e não pode ser usado. ",
               "Confira URNA_AMBIENTE e o banco.")))
    }
    if (!com_senha) {
      return(tags$div(class = "alert alert-danger",
        tags$h5("Painel sem senha do mesário"),
        tags$p(class = "mb-0", "Defina URNA_MESARIO_HASH (veja dev/gerar_hash_mesario.R).")))
    }

    if (!autenticado()) {
      return(tags$div(
        style = "max-width: 380px;",
        passwordInput("senha_mesario", "Senha do mesário", width = "100%"),
        actionButton("entrar_painel", "Entrar", class = "btn-primary w-100"),
        if (!is.null(aviso())) tags$div(class = "alert alert-danger mt-3", aviso())
      ))
    }

    progs <- isolate(tryCatch(listar_programas(pool), error = function(e) NULL))
    escolhas <- if (is.null(progs)) character() else
      stats::setNames(progs$programa_id, paste(progs$login, "—", progs$nome_oficial))

    tagList(
      uiOutput("estado"),
      uiOutput("integridade"),
      uiOutput("apuracao"),
      navset_tab(
        nav_panel("Programas", tags$div(class = "mt-3", uiOutput("programas"))),
        nav_panel("Trocar credencial", tags$div(
          class = "mt-3", style = "max-width: 600px;",
          tags$p("Para senha extraviada ou mandada ao endereço errado. A credencial ",
                 "ativa deixa de valer e passa a valer a reserva seguinte ",
                 "(arquivo de reservas, guardado com a mesa)."),
          selectInput("prog_trocar", "Programa", choices = escolhas, width = "100%"),
          actionButton("trocar", "Trocar para a reserva", class = "btn-warning")
        )),
        nav_panel("Reemitir comprovante", tags$div(
          class = "mt-3", style = "max-width: 600px;",
          tags$p("Só para programas que já votaram. O PDF é idêntico ao original."),
          selectInput("prog_comprovante", "Programa", choices = escolhas, width = "100%"),
          downloadButton("reemitir", "Baixar comprovante", class = "btn-outline-primary")
        ))
      ),
      tags$hr(),
      actionButton("sair_painel", "Sair do painel", class = "btn-outline-secondary btn-sm")
    )
  })
}

shinyApp(ui, server)
