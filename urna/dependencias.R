# Pacotes que a urna usa, incluindo os das funções em ../R.
#
# Este arquivo não é carregado pelo app. Ele existe para que
# rsconnect::writeManifest("urna") encontre todos os pacotes: o comando só
# procura dentro da pasta do app, e não veria os usados em ../R.
# O teste em tests/testthat/test-publicacao.R falha se faltar algum.
#
# Depois de mudar pacotes: rsconnect::writeManifest("urna") e commit.

library(shiny)
library(bslib)
library(htmltools)
library(DBI)
library(RPostgres)
library(pool)
library(sodium)
library(openssl)
library(jsonlite)
