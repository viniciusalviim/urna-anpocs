# Urna ANPOCS 2026 — peças da tela da urna pensadas para o celular
#
# Na sala, cada pessoa vota pelo próprio celular. Login e senha são sempre
# digitados: nada vem da URL (o teste em test-celular.R confere).

library(htmltools)

# Sem maiúscula automática, sem corretor e sem sugestão de logins já usados
# (no computador da sala, a sugestão mostraria o login de outro programa).
campo_login <- function() {
  htmltools::tags$div(
    class = "mb-3",
    htmltools::tags$label(`for` = "login", class = "form-label", "Login do programa"),
    htmltools::tags$input(id = "login", type = "text", class = "form-control",
                          autocapitalize = "none", autocorrect = "off",
                          spellcheck = "false", autocomplete = "off")
  )
}

# PIN escondido, com um botão de olho para mostrar o que foi digitado.
# inputmode e pattern: o celular abre o teclado numérico.
# autocomplete="off": o navegador não oferece guardar o PIN.
campo_senha <- function() {
  htmltools::tags$div(
    class = "mb-3",
    htmltools::tags$label(`for` = "senha", class = "form-label", "PIN"),
    htmltools::tags$div(
      class = "input-group",
      htmltools::tags$input(id = "senha", type = "password", class = "form-control",
                            inputmode = "numeric", pattern = "[0-9]*",
                            autocapitalize = "none", autocorrect = "off",
                            spellcheck = "false", autocomplete = "off"),
      htmltools::tags$button(id = "mostrar_senha", type = "button",
                             class = "btn btn-outline-secondary",
                             `aria-label` = "Mostrar senha",
                             onclick = "urnaMostrarSenha(this)",
                             shiny::icon("eye"))
    )
  )
}

# - letra de 16px nos campos: abaixo disso, o iPhone dá zoom ao tocar no
#   campo e a tela sai do lugar;
# - botões com pelo menos 48px de altura: área de toque de dedo;
# - texto longo (nome de programa, de chapa) quebra em vez de alargar a
#   tela e criar rolagem lateral;
# - overflow-x: clip (e não hidden): corta o que sobrar dos lados sem
#   impedir o CONFIRMA de ficar fixo na parte de baixo da tela;
# - os membros da chapa ficam numa caixa de altura fixa (.urna-membros),
#   com rolagem própria: número, nome da chapa, caixa e CONFIRMAR cabem na
#   tela sem rolar a página (conferido a 375 x 812 e em tela de computador).
#   A altura da caixa é a que a tela comporta (altura da janela menos ~34rem
#   do que vem acima e abaixo dela), entre 6rem e 16rem; não depende de
#   quantos nomes a chapa tem. dvh desconta a barra de endereço do celular;
#   navegador antigo usa a linha com vh;
# - o bloco do CONFIRMA (.urna-confirma) ainda fica fixo embaixo, como
#   reserva para telas mais baixas que essas.
estilo_celular <- function() {
  htmltools::tags$style(htmltools::HTML("
    html, body { overflow-x: clip; }
    body { overflow-wrap: anywhere; }
    .form-control, .form-select { font-size: 16px; }
    .form-control-lg { font-size: 1.5rem; }
    .btn { min-height: 48px; white-space: normal; }
    #numero { font-size: 2rem; text-align: center; letter-spacing: 0.2em; }
    .urna-caixa { max-width: 480px; margin: 1.5rem auto 0.5rem auto; }
    .urna-faixa-teste { background: #c62828; color: white; font-weight: bold;
                        text-align: center; padding: 0.5rem; font-size: 1.05rem; }
    .urna-titulo { margin-bottom: 0.15rem; }
    .urna-subtitulo { font-size: 0.9rem; margin-bottom: 0.4rem; }
    .urna-linha { margin: 0.4rem 0 0.6rem 0; }
    .urna-votando { margin-bottom: 0.5rem; line-height: 1.3; }
    .urna-cartao { padding: 0.75rem 1rem 0.5rem 1rem; }
    .urna-chapa-numero { font-size: 0.8rem; text-transform: uppercase;
                         letter-spacing: 0.03em; color: #6c757d; }
    .urna-rolar-aviso { font-size: 0.8rem; font-style: italic; color: #6c757d;
                        margin-bottom: 0.2rem; }
    .urna-membros-moldura { position: relative; }
    .urna-membros { height: clamp(6rem, calc(100vh - 34rem), 16rem);
                    height: clamp(6rem, calc(100dvh - 34rem), 16rem);
                    overflow-y: auto; overscroll-behavior: contain;
                    -webkit-overflow-scrolling: touch; padding: 0 0.25rem 1.75rem 0;
                    border-top: 1px solid #e9ecef; }
    .urna-membros-esmaecido { position: absolute; left: 0; right: 0; bottom: 0;
                              height: 2rem; pointer-events: none;
                              background: linear-gradient(to bottom, rgba(255, 255, 255, 0),
                                                          var(--bs-card-bg, #fff)); }
    .urna-cargo { font-size: 0.75rem; font-weight: 600; text-transform: uppercase;
                  letter-spacing: 0.03em; color: #6c757d; margin-top: 0.45rem; }
    .urna-membro { font-size: 1rem; line-height: 1.3; }
    .urna-confirma { position: sticky; bottom: 0; z-index: 10; margin-top: 0.25rem;
                     padding: 0.5rem 0; background: var(--bs-body-bg, #fff); }
    @media (max-width: 576px) {
      .urna-caixa { margin-top: 0.5rem; }
      .urna-titulo { font-size: 1.35rem; }
      .urna-subtitulo { font-size: 0.85rem; }
    }
  "))
}

# Faixa vermelha do modo teste (a urna mostra quando o modo não é 'oficial').
faixa_teste_html <- function() {
  htmltools::tags$div(class = "urna-faixa-teste", FAIXA_TESTE)
}

# Topo de todas as telas da urna.
cabecalho_urna <- function() {
  htmltools::tagList(
    htmltools::tags$h3(class = "urna-titulo", "Eleição ANPOCS 2026"),
    htmltools::tags$p(class = "text-muted urna-subtitulo",
                      "Conselho Diretivo e Conselho Fiscal — biênio 2027–2028"),
    htmltools::tags$hr(class = "urna-linha")
  )
}

# A parte de cima da cédula: quem está votando, o campo do número (teclado
# numérico) e os botões ABSTENÇÃO (só se permitida) e CORRIGE.
cabecalho_cedula <- function(nome_oficial, permite_abstencao) {
  htmltools::tagList(
    htmltools::tags$p(class = "text-muted urna-votando",
                      "Votando como: ", htmltools::tags$strong(nome_oficial)),
    htmltools::tags$label(`for` = "numero", class = "form-label mb-1",
                          "Digite o número da chapa"),
    htmltools::tags$input(id = "numero", type = "text", class = "form-control form-control-lg",
                          inputmode = "numeric", pattern = "[0-9]*",
                          autocomplete = "off", value = ""),
    htmltools::tags$div(
      class = "d-flex gap-2 mt-2",
      if (isTRUE(permite_abstencao)) {
        shiny::actionButton("abstencao", "ABSTENÇÃO", class = "btn-outline-dark btn-lg flex-fill")
      },
      shiny::actionButton("corrige", "CORRIGE", class = "btn-warning btn-lg flex-fill")
    )
  )
}

# O que aparece ao digitar uma opção válida:
# - o número e o nome da chapa;
# - os membros, agrupados pelo cargo ("Nome (Instituição)"), numa CAIXA DE
#   ALTURA FIXA com rolagem própria (a tela não cresce com os 13 nomes), com
#   o aviso discreto "role para ver todos os membros" e um esmaecido na
#   borda de baixo, para ficar claro que há mais nomes;
# - o botão de confirmar, que envia a opção escrita nele mesmo (data-opcao).
# Na abstenção, só o nome e o botão.
cartao_opcao <- function(d) {
  grupos <- agrupar_membros(d$membros)
  htmltools::tagList(
    htmltools::tags$div(
      class = "card mt-2",
      htmltools::tags$div(
        class = "card-body urna-cartao",
        if (length(grupos)) {
          htmltools::tags$div(class = "urna-chapa-numero", paste("Número", d$opcao))
        },
        htmltools::tags$h5(class = "card-title mb-1", d$nome),
        if (length(grupos)) {
          htmltools::tagList(
            htmltools::tags$div(class = "urna-rolar-aviso", "role para ver todos os membros"),
            htmltools::tags$div(
              class = "urna-membros-moldura",
              htmltools::tags$div(
                class = "urna-membros",
                lapply(grupos, function(g) {
                  htmltools::tags$div(
                    class = "urna-grupo",
                    htmltools::tags$div(class = "urna-cargo", g$cargo),
                    lapply(g$pessoas, function(p) htmltools::tags$div(class = "urna-membro", p))
                  )
                })
              ),
              htmltools::tags$div(class = "urna-membros-esmaecido")
            )
          )
        }
      )
    ),
    htmltools::tags$div(
      class = "urna-confirma",
      htmltools::tags$button(
        id = "confirma", type = "button",
        class = "btn btn-success btn-lg w-100",
        `data-opcao` = d$opcao,
        onclick = "urnaConfirmar(this)",
        rotulo_confirma(d$opcao)
      )
    )
  )
}

# No iPhone e no iPad, o PDF costuma abrir numa aba em vez de baixar.
# O aviso só aparece nesses aparelhos.
aviso_comprovante_iphone <- function() {
  htmltools::tagList(
    htmltools::tags$div(
      id = "aviso_iphone", class = "alert alert-info small", style = "display: none;",
      htmltools::tags$strong("No iPhone ou iPad: "),
      "se o comprovante abrir numa nova aba, toque em Compartilhar ",
      "(o quadrado com a seta para cima) e depois em ",
      htmltools::tags$strong("Salvar em Arquivos."),
      " Depois, volte para esta aba."
    ),
    htmltools::tags$script(htmltools::HTML(
      "(function() {
         var ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
                   (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
         var el = document.getElementById('aviso_iphone');
         if (ios && el) el.style.display = 'block';
       })();"
    ))
  )
}
