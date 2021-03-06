theme_report <- function(base_size = 11,
                         strip_text_size = 12,
                         strip_text_margin = 5,
                         subtitle_size = 13,
                         subtitle_margin = 10,
                         plot_title_size = 16,
                         plot_title_margin = 10,
                         ...) {
    ret <- ggplot2::theme_minimal(base_family = "Roboto-Regular",
                                  base_size = base_size, ...)
    ret$strip.text <- ggplot2::element_text(hjust = 0, size=strip_text_size,
                                            margin=margin(b=strip_text_margin),
                                            family="Roboto-Bold")
    ret$plot.subtitle <- ggplot2::element_text(hjust = 0, size=subtitle_size,
                                               margin=margin(b=subtitle_margin),
                                               family="PT Sans")
    ret$plot.title <- ggplot2::element_text(hjust = 0, size = plot_title_size,
                                             margin=margin(b=plot_title_margin),
                                            family="Oswald")
    ret
}

organiza_aba <- function(aba_df){
    names(aba_df)[1] = "estado"
    
    aba_df %>%  
        filter(!(estado %in% c("NORTE", "NORDESTE", "SUL", "SUDESTE", "C. OESTE", "BRASIL"))) %>% 
        select(-matches("TOTAL")) %>% 
        gather(key = "candidato", value = "votos", -estado)
}

gs_read_all <- function(ss, delay = 4){ 
    ws_names <- gs_ws_ls(ss)
    
    gs_read_delayed <- function(ss, ws){
        result <- gs_read(ss, ws)
        
        Sys.sleep(delay)
        return(result) 
    }
    
    worksheets <- map(ws_names, ~ gs_read_delayed(ss, ws = .x)) %>% 
        set_names(ws_names)
    
    return(worksheets)
}


import_presidente <- function(){
    library(tidyverse)
    presidente_gs = googlesheets::gs_title("Presidente. Votos dos candidatos (1989-2014)")
        
    
    library(googlesheets)
    resultado = gs_read_all(presidente_gs, delay = 10)
    
    votos_long = resultado %>% 
        map2_df(names(resultado), ~ organiza_aba(.x) %>% mutate(eleicao = .y)) %>% 
        separate(eleicao, into = c("cargo", "ano", "turno"), extra = "merge") 
    
    votos_long %>% 
        write_csv(here::here("data/votos_tidy_long.csv"))
    votos_long %>% 
        select(-cargo) %>% 
        nest(-ano, -turno, -estado) %>% 
        jsonlite::write_json(here::here("data/votos_tidy_long.json"))
}

import_comparecimento <- function(){
    library(tidyverse)
    presidente_gs = googlesheets::gs_title("Copy of 1.3. Presidente. Comparecimento, brancos e nulos (1989-2014)")
    
    library(googlesheets)
    resultado = gs_read_all(presidente_gs, delay = 10)
    
    votos_long = resultado %>%
        map2_df(names(resultado),
                ~ organiza_aba(.x) %>% mutate(votos = as.character(votos), eleicao = .y)) %>%
        dplyr::rename(situacao = candidato) %>%
        filter(situacao != "ELEITORADO") %>%
        mutate(ano = readr::parse_number(eleicao),
               turno = stringr::str_sub(eleicao,-2,-1))
    
    votos_long %>% 
        write_csv(here::here("data/comparecimento_tidy_long.csv"))
}

import_votos_camara <- function(){
    library(tidyverse)
    presidente_gs = googlesheets::gs_title("Copy of 2.1. Câmara dos Deputados. Votos dos partidos (1982-2014)")
    
    library(googlesheets)
    resultado = gs_read_all(presidente_gs, delay = 10)
    
    votos_long = resultado %>%
        map2_df(names(resultado),
                ~ .x %>% organiza_aba() %>% mutate(eleicao = .y)) %>%
        dplyr::rename(partido = candidato) %>%
        mutate(ano = readr::parse_number(eleicao))
    
    votos_long %>% 
        write_csv(here::here("data/partidos_tidy_long.csv"))
}


read_projectdata <- function(){

}

data_presidente_tidy <- function(data_path) {
    library(tidyverse)
    library(readr)
    
    votos <- read_csv(data_path)
    
    votos_presidente <- votos %>%
        mutate(coligacao = sapply(str_extract_all(candidato, "\\b[A-Z]+\\b|PCdoB|PDCdoB|PTdoB"), paste, collapse= ' ')) %>% 
        mutate(partido = gsub("([A-Za-z]+).*", "\\1", coligacao)) %>%
        rowwise() %>% 
        mutate(nome = gsub(paste0("\\", partido, ".*", "|\\("), "", candidato)) %>% 
        na.omit() %>% 
        filter(estado != "TOTAL")
    
    return(votos_presidente)
}

dados_presidente_porcentagem <- function() {
    
    library(here)
    data_path <- here::here("data/votos_tidy_long.csv")
    
    votos <- data_presidente_tidy(data_path)
    
    votos_presidente <- votos %>%
        group_by(ano, turno) %>% 
        mutate(total_votos = sum(votos)) %>% 
        mutate(porcentagem_brasil = (votos/total_votos) * 100) %>% 
        ungroup() %>% 
        select(estado, nome, partido, coligacao, votos, porcentagem_brasil, cargo, ano, turno)
    
    votos_presidente %>% 
        write_csv(here::here("data/votos_presidente_tidy.csv"))
}
