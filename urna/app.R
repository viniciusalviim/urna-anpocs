# Urna ANPOCS 2026 — app do votante
#
# Etapas 3b, 4 e 5: login, cédula, confirmação e comprovante.
#
# Para rodar: shiny::runApp("urna", launch.browser = TRUE)
#
# Invariante 7: a opção escolhida vive só no campo da tela até o CONFIRMA.
# Nenhum reactiveVal guarda voto; `tela` e `votante` são só navegação.

library(shiny)
library(bslib)

# Funções compartilhadas com o painel (uma pasta acima).
for (f in sort(list.files("../R", pattern = "\\.R$", full.names = TRUE))) {
  source(f)
}

pool <- conectar_pool()
onStop(function() pool::poolClose(pool))

MENSAGENS <- list(
  credenciais_invalidas = "Login ou senha incorretos.",
  urna_nao_aberta       = "A urna ainda não foi aberta pela mesa.",
  programa_inapto       = "Este programa não consta como apto a votar.",
  ja_votou              = "Este programa já votou nesta eleição."
)

# Recusas de registrar_voto(). `final = TRUE` encerra a sessão de voto:
# tentar de novo não adianta.
RECUSAS_VOTO <- list(
  urna_nao_aberta      = list(final = FALSE,
    msg = "A urna não está aberta. O voto não foi registrado."),
  urna_nao_configurada = list(final = FALSE,
    msg = "A urna não está aberta. O voto não foi registrado."),
  opcao_invalida       = list(final = FALSE,
    msg = "Número inexistente. O voto não foi registrado."),
  erro_interno         = list(final = FALSE,
    msg = "Não foi possível registrar o voto. Tente de novo."),
  credencial_invalida  = list(final = TRUE,
    msg = "Esta credencial não é mais válida. Procure a mesa."),
  ja_votou             = list(final = TRUE,
    msg = "Este programa já votou. Este voto não foi registrado.")
)

# Telas finais (voto depositado, recusa definitiva) voltam sozinhas ao login
# depois deste tempo: higiene do computador presencial.
SEGUNDOS_FECHAMENTO <- 60

ui <- page_fixed(
  theme = bs_theme(version = 5),
  title = "Urna ANPOCS 2026",

  tags$script(HTML(
    "// Enter envia o formulário de login (e só ele).
     document.addEventListener('keydown', function(e) {
       if (e.key === 'Enter') {
         var b = document.getElementById('entrar');
         if (b) b.click();
       }
     });

     // CONFIRMA envia a opção que está escrita no próprio botão, ou seja,
     // a que estava na tela ao lado dele. Desabilita na hora para que um
     // clique duplo não mande duas vezes. priority 'event' faz o servidor
     // receber de novo a mesma opção, se for preciso tentar outra vez.
     function urnaConfirmar(b) {
       b.disabled = true;
       Shiny.setInputValue('confirma', b.dataset.opcao, {priority: 'event'});
     }

     $(document).on('shiny:connected', function() {
       Shiny.addCustomMessageHandler('reabilitar_confirma', function(x) {
         var b = document.getElementById('confirma');
         if (b) b.disabled = false;
       });
     });

     // Tela final: conta os segundos na tela e, no fim, clica em Sair.
     // Se a pessoa sair antes, o elemento some e a contagem para.
     var urnaTimer = null;
     function urnaFechamento(segundos) {
       if (urnaTimer) clearInterval(urnaTimer);
       var resta = segundos;
       urnaTimer = setInterval(function() {
         var el = document.getElementById('contagem');
         if (!el) { clearInterval(urnaTimer); urnaTimer = null; return; }
         resta = resta - 1;
         el.textContent = Math.max(resta, 0);
         if (resta <= 0) {
           clearInterval(urnaTimer); urnaTimer = null;
           var s = document.getElementById('sair');
           if (s) s.click();
         }
       }, 1000);
     }

     // Download automático do comprovante: espera o link de download ficar
     // pronto (o Shiny preenche o endereço dele) e clica uma vez.
     function urnaBaixarComprovante() {
       var tentativas = 0;
       var t = setInterval(function() {
         var a = document.getElementById('comprovante');
         tentativas++;
         if (a && a.getAttribute('href') && a.getAttribute('href') !== '#') {
           clearInterval(t);
           a.click();
         } else if (tentativas > 50) {
           clearInterval(t);   // desiste em silêncio: o botão continua lá
         }
       }, 100);
     }"
  )),

  uiOutput("faixa"),

  tags$div(
    style = "max-width: 480px; margin: 3rem auto;",
    tags$h3("Eleição ANPOCS 2026"),
    tags$p(class = "text-muted",
           "Conselho Diretivo e Conselho Fiscal — biênio 2027–2028"),
    tags$hr(),
    uiOutput("tela")
  )
)

server <- function(input, output, session) {

  tela    <- reactiveVal("login")  # login | cedula | depositado | encerrado
  votante <- reactiveVal(NULL)     # preenchido depois do login
  cedula  <- reactiveVal(NULL)     # conteúdo da cédula (chapas), não o voto
  aviso   <- reactiveVal(NULL)     # mensagem do login ou da tela encerrado
  aviso_voto <- reactiveVal(NULL)  # mensagem de recusa na cédula

  # ---- login -------------------------------------------------------------

  observeEvent(input$entrar, {
    if (tela() != "login") return()
    aviso(NULL)
    r <- autenticar(pool, input$login, input$senha)

    if (isTRUE(r$ok)) {
      cedula(ler_cedula(pool))
      aviso_voto(NULL)
      votante(r)
      tela("cedula")
    } else {
      msg <- MENSAGENS[[r$motivo]]
      aviso(if (is.null(msg)) "Não foi possível entrar." else msg)
    }
  })

  observeEvent(input$sair, {
    votante(NULL)
    cedula(NULL)
    aviso(NULL)
    aviso_voto(NULL)
    tela("login")
  })

  # ---- cédula ------------------------------------------------------------

  observeEvent(input$abstencao, {
    updateTextInput(session, "numero", value = TEXTO_ABSTENCAO)
  })

  # Mudou o número: a recusa anterior não vale mais para o que está na tela.
  observeEvent(input$numero, aviso_voto(NULL), ignoreInit = TRUE)

  observeEvent(input$corrige, {
    aviso_voto(NULL)
    updateTextInput(session, "numero", value = "")
  })

  observeEvent(input$confirma, {
    # Cliques atrasados, depois do voto ou do Sair, não fazem nada.
    if (tela() != "cedula") return()
    v <- votante()
    if (is.null(v)) return()

    aviso_voto(NULL)
    r <- tryCatch({
      con <- pool::localCheckout(pool)
      registrar_voto(con, v$programa_id, v$credencial_id, input$confirma)
    }, error = function(e) list(ok = FALSE, motivo = "erro_interno"))

    # Invariante 6: "voto depositado" só depois do COMMIT.
    if (isTRUE(r$ok)) {
      tela("depositado")
      return()
    }

    recusa <- RECUSAS_VOTO[[r$motivo]]
    if (is.null(recusa)) recusa <- RECUSAS_VOTO$erro_interno

    if (recusa$final) {
      aviso(recusa$msg)
      tela("encerrado")
    } else {
      aviso_voto(recusa$msg)
      session$sendCustomMessage("reabilitar_confirma", TRUE)
    }
  })

  # Descrição do que está no campo. Recalcula a cada digitação sem redesenhar
  # a cédula inteira (senão o campo perderia o foco).
  output$escolha <- renderUI({
    ced <- cedula()
    req(ced)
    d <- descrever_opcao(ced, input$numero)

    if (d$estado == "vazio") return(NULL)

    if (d$estado == "inexistente") {
      return(tags$div(class = "alert alert-warning mt-3",
                      tags$strong("Número inexistente")))
    }

    tagList(
      tags$div(
        class = "card mt-3",
        tags$div(
          class = "card-body",
          tags$h5(class = "card-title", d$nome),
          if (!is.null(d$membros) && nrow(d$membros) > 0) {
            tags$ul(class = "mb-0", lapply(seq_len(nrow(d$membros)), function(i) {
              tags$li(tags$strong(d$membros$nome[i]), " — ", d$membros$cargo[i])
            }))
          }
        )
      ),
      tags$button(
        id = "confirma", type = "button",
        class = "btn btn-success btn-lg w-100 mt-3",
        `data-opcao` = d$opcao,
        onclick = "urnaConfirmar(this)",
        rotulo_confirma(d$opcao)
      )
    )
  })

  output$aviso_voto <- renderUI({
    a <- aviso_voto()
    if (!is.null(a)) tags$div(class = "alert alert-danger mt-3", a)
  })

  # ---- comprovante -------------------------------------------------------

  # Lê do banco a cada download: nada do comprovante fica guardado na sessão,
  # e o arquivo é o mesmo que o painel reemite.
  output$comprovante <- downloadHandler(
    filename = function() {
      v <- isolate(votante())
      d <- if (!is.null(v)) dados_comprovante(pool, v$programa_id)
      if (is.null(d)) "comprovante.pdf"
      else paste0("comprovante_", d$comprovante_id, ".pdf")
    },
    content = function(file) {
      v <- isolate(votante())
      d <- if (!is.null(v)) dados_comprovante(pool, v$programa_id)
      if (is.null(d)) stop("Comprovante indisponível.")
      gerar_comprovante_pdf(d, file)
      registrar_log(pool, "comprovante_baixado", v$programa_id)
    },
    contentType = "application/pdf"
  )

  # ---- faixa de teste ----------------------------------------------------

  # Relida a cada troca de tela. Qualquer modo que não seja 'oficial'
  # (inclusive erro ao ler) mostra a faixa.
  output$faixa <- renderUI({
    tela()
    modo <- tryCatch(ler_modo_urna(pool), error = function(e) NA_character_)
    if (e_modo_teste(modo)) {
      tags$div(
        style = paste("background: #c62828; color: white; font-weight: bold;",
                      "text-align: center; padding: 0.6rem; font-size: 1.15rem;"),
        FAIXA_TESTE
      )
    }
  })

  # ---- telas -------------------------------------------------------------

  aviso_fechamento <- function() {
    tagList(
      tags$p(class = "alert alert-secondary mt-3 mb-3",
             "Esta tela se fecha sozinha em ",
             tags$strong(tags$span(id = "contagem", SEGUNDOS_FECHAMENTO)),
             " segundos."),
      tags$script(HTML(sprintf("urnaFechamento(%d);", SEGUNDOS_FECHAMENTO)))
    )
  }

  output$tela <- renderUI({
    switch(tela(),

      login = tagList(
        textInput("login", "Login do programa", width = "100%"),
        passwordInput("senha", "Senha", width = "100%"),
        actionButton("entrar", "Entrar", class = "btn-primary w-100"),
        if (!is.null(aviso())) {
          tags$div(class = "alert alert-danger mt-3", aviso())
        },
        tags$p(class = "text-muted small mt-3 mb-0",
               "Recomendamos votar pelo computador.")
      ),

      cedula = {
        v   <- isolate(votante())
        ced <- isolate(cedula())
        tagList(
          tags$p(class = "text-muted mb-3",
                 "Votando como: ", tags$strong(v$nome_oficial)),
          tags$label(`for` = "numero", class = "form-label",
                     "Digite o número da chapa"),
          tags$input(id = "numero", type = "text", class = "form-control form-control-lg",
                     inputmode = "numeric", pattern = "[0-9]*",
                     autocomplete = "off", value = ""),
          tags$div(
            class = "d-flex gap-2 mt-3",
            if (isTRUE(ced$permite_abstencao)) {
              actionButton("abstencao", "ABSTENÇÃO", class = "btn-outline-dark flex-fill")
            },
            actionButton("corrige", "CORRIGE", class = "btn-warning flex-fill")
          ),
          uiOutput("escolha"),
          uiOutput("aviso_voto")
        )
      },

      depositado = tagList(
        tags$div(class = "alert alert-success text-center",
                 tags$h4(class = "mb-0", "VOTO DEPOSITADO")),
        tags$p("O comprovante em PDF está sendo baixado. Ele comprova a ",
               "participação do programa, não o voto."),
        downloadButton("comprovante", "Baixar comprovante novamente",
                       class = "btn-outline-primary w-100"),
        aviso_fechamento(),
        actionButton("sair", "Sair", class = "btn-outline-secondary"),
        tags$script(HTML("urnaBaixarComprovante();"))
      ),

      encerrado = tagList(
        tags$div(class = "alert alert-danger", aviso()),
        aviso_fechamento(),
        actionButton("sair", "Sair", class = "btn-outline-secondary")
      )
    )
  })
}

shinyApp(ui, server)
