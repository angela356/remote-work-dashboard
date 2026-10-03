invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))
# Extra aggregates for the readability pass
#  - euro_wstatus.json : % usually working from home, employees vs self-employed, latest year, by country (Eurostat LFS)
#  - who5_risk.json    : survey-weighted % of workers with WHO-5 below 50 (low well-being), by WFH frequency and wave
suppressPackageStartupMessages({ library(dplyr); library(jsonlite) })
RDS <- Sys.getenv("RDS_DIR", "rds"); OUT <- "data"

e <- readRDS(file.path(RDS, "euro.rds"))
ws <- e %>% filter(freq == "USU", sex == "T", age == "Y_GE15", wstatus %in% c("SAL", "SELF"),
                   !is.na(value), nchar(geo) == 2)
yr <- max(ws$year)
ws <- ws %>% filter(year == yr) %>% select(geo, country, wstatus, value) %>%
  tidyr::pivot_wider(names_from = wstatus, values_from = value) %>%
  filter(!is.na(SAL), !is.na(SELF)) %>%
  transmute(geo, country, year = yr, employees = round(SAL, 1), self_employed = round(SELF, 1)) %>%
  arrange(desc(employees))
write_json(ws, file.path(OUT, "euro_wstatus.json"), auto_unbox = TRUE)
cat("euro_wstatus:", nrow(ws), "countries, year", yr, "\n")

WFH <- c("Never", "Rarely", "Sometimes", "Often", "Always")
risk <- function(d, wave) {
  d %>% filter(!is.na(who5_index), !is.na(weight), loc_home %in% WFH) %>%
    group_by(wfh = as.character(loc_home)) %>%
    summarise(pct_low = round(100 * sum(weight * (who5_index < 50)) / sum(weight), 1),
              n = n(), .groups = "drop") %>%
    mutate(wave = wave, wfh = factor(wfh, WFH)) %>% arrange(wfh) %>% mutate(wfh = as.character(wfh))
}
r <- bind_rows(risk(readRDS(file.path(RDS, "ew15.rds")), "2015"),
               risk(readRDS(file.path(RDS, "ew21.rds")), "2021"),
               risk(readRDS(file.path(RDS, "ew24.rds")), "2024"))
write_json(r, file.path(OUT, "who5_risk.json"), auto_unbox = TRUE)
print(r)
