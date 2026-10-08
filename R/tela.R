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
# - o bloco do CONFIRMA (.urna-confirma) fica fixo embaixo enquanto a lista
#   de membros da chapa estiver à vista: com 13 nomes, ele sairia da tela.
estilo_celular <- function() {
  htmltools::tags$style(htmltools::HTML("
    html, body { overflow-x: clip; }
    body { overflow-wrap: anywhere; }
    .form-control, .form-select { font-size: 16px; }
    .form-control-lg { font-size: 1.5rem; }
    .btn { min-height: 48px; white-space: normal; }
    #numero { font-size: 2rem; text-align: center; letter-spacing: 0.2em; }
    .urna-caixa { max-width: 480px; margin: 1.5rem auto; }
    .urna-cargo { font-size: 0.8rem; font-weight: 600; text-transform: uppercase;
                  letter-spacing: 0.03em; color: #6c757d; margin-top: 0.6rem; }
    .urna-membro { font-size: 1rem; line-height: 1.35; }
    .urna-confirma { position: sticky; bottom: 0; z-index: 10; margin-top: 0.5rem;
                     padding: 0.75rem 0; background: var(--bs-body-bg, #fff);
                     box-shadow: 0 -8px 8px -8px rgba(0, 0, 0, 0.25); }
    @media (max-width: 576px) {
      .urna-caixa { margin-top: 0.75rem; }
      h3 { font-size: 1.4rem; }
    }
  "))
}

# O que aparece ao digitar uma opção válida: o nome da chapa, os membros
# agrupados pelo cargo ("Nome (Instituição)") e o botão de confirmar, que
# envia a opção escrita nele mesmo (data-opcao). Na abstenção, só o nome.
cartao_opcao <- function(d) {
  grupos <- agrupar_membros(d$membros)
  htmltools::tagList(
    htmltools::tags$div(
      class = "card mt-3",
      htmltools::tags$div(
        class = "card-body",
        htmltools::tags$h5(class = "card-title mb-1", d$nome),
        lapply(grupos, function(g) {
          htmltools::tags$div(
            class = "urna-grupo",
            htmltools::tags$div(class = "urna-cargo", g$cargo),
            lapply(g$pessoas, function(p) htmltools::tags$div(class = "urna-membro", p))
          )
        })
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
