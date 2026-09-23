# Urna ANPOCS 2026 — app do votante
#
# Etapa 3b: apenas a tela de login. A cédula é a etapa 4.
#
# Para rodar: shiny::runApp("urna", launch.browser = TRUE)

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

ui <- page_fixed(
  theme = bs_theme(version = 5),
  title = "Urna ANPOCS 2026",

  # Enter envia o formulário.
  tags$script(HTML(
    "document.addEventListener('keydown', function(e) {
       if (e.key === 'Enter') {
         var b = document.getElementById('entrar');
         if (b) b.click();
       }
     });"
  )),

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

  votante <- reactiveVal(NULL)   # preenchido depois do login
  aviso   <- reactiveVal(NULL)

  observeEvent(input$entrar, {
    aviso(NULL)
    r <- autenticar(pool, input$login, input$senha)

    if (isTRUE(r$ok)) {
      votante(r)
    } else {
      msg <- MENSAGENS[[r$motivo]]
      aviso(if (is.null(msg)) "Não foi possível entrar." else msg)
    }
  })

  observeEvent(input$sair, {
    votante(NULL)
    aviso(NULL)
  })

  output$tela <- renderUI({
    v <- votante()

    if (is.null(v)) {
      tagList(
        textInput("login", "Login do programa", width = "100%"),
        passwordInput("senha", "Senha", width = "100%"),
        actionButton("entrar", "Entrar", class = "btn-primary w-100"),
        if (!is.null(aviso())) {
          tags$div(class = "alert alert-danger mt-3", aviso())
        }
      )
    } else {
      tagList(
        tags$div(class = "alert alert-success",
                 tags$strong("Credencial aceita.")),
        tags$p(tags$strong(v$nome_oficial)),
        tags$p(class = "text-muted",
               "A cédula de votação entra na próxima etapa."),
        actionButton("sair", "Sair", class = "btn-outline-secondary")
      )
    }
  })
}

shinyApp(ui, server)
