RAW_DIR <- Sys.getenv("RAW_DIR", "raw_data")   # folder holding the original data files
# R-MAP re-extraction with unambiguous column matching
# Fixes the bug where "In.the.Office.*Hours" (case-insensitive) also matched the
# question stem of the "Remotely Hours" column, so office_hours == remote_hours.
suppressPackageStartupMessages({ library(readxl); library(dplyr); library(jsonlite); library(tidyr) })
OUT <- "data"
raw <- read_excel(file.path(RAW_DIR, "RMAP_Data_Descriptor_Data_5972.xlsx"), sheet = 1)
nm  <- names(raw)

# exact-suffix matching: a column is identified by how its name ENDS, never by the stem
by_suffix <- function(suffix) {
  hit <- nm[endsWith(nm, suffix)]
  if (length(hit) != 1) stop(sprintf("suffix '%s' matched %d columns", suffix, length(hit)))
  hit
}
by_pattern_unique <- function(pat) {
  hit <- grep(pat, nm, value = TRUE)
  if (length(hit) != 1) stop(sprintf("pattern '%s' matched %d columns", pat, length(hit)))
  hit
}
LIK <- c("Strongly Disagree"=1,"Disagree"=2,"Somewhat Disagree"=3,"Neutral"=4,
         "Somewhat Agree"=5,"Agree"=6,"Strongly Agree"=7)
lik <- function(col) {
  v <- raw[[col]]
  if (is.numeric(v)) return(as.numeric(v))
  out <- unname(LIK[trimws(as.character(v))])
  num <- suppressWarnings(as.numeric(as.character(v)))
  ifelse(is.na(out), num, out)
}

c_remote <- by_suffix("Remotely...Hours.")
c_office <- by_suffix("In.the.Office..Hours.")
stopifnot(c_remote != c_office)

rm <- tibble(
  remote_hours     = as.numeric(raw[[c_remote]]),
  office_hours     = as.numeric(raw[[c_office]]),
  flex_important   = lik(by_pattern_unique("flexibility.to.choose.my.work.location")),
  remote_pos_life  = lik(by_pattern_unique("positively.impacts.my.personal.life")),
  prefer_remote    = lik(by_pattern_unique("prefer.remote.work.over.in.office")),
  career_neg       = lik(by_pattern_unique("negatively.impacts.my.career")),
  wlb_difficult    = lik(by_pattern_unique("difficult.to.maintain.a.healthy.work.life")),
  more_challenging = lik(by_pattern_unique("more.challenging.than.in.office")),
  less_productive  = lik(by_pattern_unique("less.productive.while.working.remotely")),
  commute_min      = suppressWarnings(as.numeric(raw[[by_pattern_unique("time.do.you.spend.on.commuting")]])),
  industry         = as.character(raw[[by_pattern_unique("industry.sector")]])
)
cat("rows:", nrow(rm), "\n")
cat("remote==office share (both present):",
    round(mean(rm$remote_hours == rm$office_hours, na.rm = TRUE) * 100, 1), "%\n")

rm <- rm %>%
  mutate(
    total_hours = remote_hours + office_hours,
    pct_remote  = ifelse(!is.na(total_hours) & total_hours > 0, remote_hours / total_hours * 100, NA_real_),
    commute_min = ifelse(commute_min < 0 | commute_min > 180, NA, commute_min),   # plausibility cap (report §4.2)
    band4 = cut(pct_remote, c(-Inf, 25, 50, 75, Inf), right = FALSE,
                labels = c("0-25%", "25-50%", "50-75%", "75-100%")),
    band6 = case_when(pct_remote == 0 ~ "0% (office only)",
                      pct_remote < 25 ~ "1-24%",
                      pct_remote < 50 ~ "25-49%",
                      pct_remote < 75 ~ "50-74%",
                      pct_remote < 100 ~ "75-99%",
                      pct_remote == 100 ~ "100% (fully remote)"),
    # --- indices exactly as documented in D2 §5.2-5.4 (R-MAP formulas are direction-correct) ---
    P_rmap = (7 - less_productive) / 6 * 100,
    W_rmap = rowMeans(cbind((remote_pos_life - 1) / 6 * 100,
                            (7 - wlb_difficult) / 6 * 100,
                            (7 - more_challenging) / 6 * 100), na.rm = TRUE),
    W_rmap = ifelse(is.nan(W_rmap), NA, W_rmap),
    # legacy 1-7 scores kept for reference
    prod = 8 - less_productive, wlb = 8 - wlb_difficult,
    # weekly commuting hours avoided: one-way minutes x 2 trips x 5 workdays x remote share
    hours_saved = commute_min * 2 * 5 * (pct_remote / 100) / 60
  )

band6_levels <- c("0% (office only)","1-24%","25-49%","50-74%","75-99%","100% (fully remote)")
cat("\npct_remote summary:\n"); print(summary(rm$pct_remote))
print(table(rm$band6, useNA = "ifany")[band6_levels])

# 1) distribution of remote share
dist <- rm %>% filter(!is.na(band6)) %>% count(band = band6) %>%
  mutate(band = factor(band, band6_levels)) %>% arrange(band) %>%
  mutate(band = as.character(band), pct = round(n / sum(n) * 100, 1))
write_json(dist, file.path(OUT, "pct_remote_dist.json"), auto_unbox = TRUE)

# 2) scatter data: sector x 4-band
sc <- rm %>% filter(!is.na(band4), !is.na(industry), industry != "") %>%
  group_by(sector = industry, pct_band = as.character(band4)) %>%
  summarise(prod = round(mean(prod, na.rm = TRUE), 2), wlb = round(mean(wlb, na.rm = TRUE), 2),
            P = round(mean(P_rmap, na.rm = TRUE), 1), W = round(mean(W_rmap, na.rm = TRUE), 1),
            n = n(), .groups = "drop") %>% filter(n >= 20)
write_json(sc, file.path(OUT, "rmap_scatter.json"), auto_unbox = TRUE)
cat("\nrmap_scatter:", nrow(sc), "cells | bands:", paste(sort(unique(sc$pct_band)), collapse = ", "), "\n")

# 3) indices by remote-intensity band (dose-response, mean + 95% CI)
ci <- function(x) { x <- x[!is.na(x)]; m <- mean(x); s <- sd(x) / sqrt(length(x)); c(m, m - 1.96 * s, m + 1.96 * s, length(x)) }
idx <- bind_rows(lapply(c("P_rmap", "W_rmap"), function(v)
  rm %>% filter(!is.na(band6)) %>% group_by(band = band6) %>%
    summarise(r = list(ci(.data[[v]])), .groups = "drop") %>%
    mutate(index = v, mean = sapply(r, `[`, 1), lo = sapply(r, `[`, 2),
           hi = sapply(r, `[`, 3), n = sapply(r, `[`, 4)) %>% select(-r)))
idx <- idx %>% mutate(band = factor(band, band6_levels)) %>% arrange(index, band) %>%
  mutate(band = as.character(band), across(c(mean, lo, hi), ~ round(., 1)))
write_json(idx, file.path(OUT, "rmap_index_band.json"), auto_unbox = TRUE)
cat("\nR-MAP indices by band:\n"); print(idx, n = 20)

# 4) perception items by band
items <- c(flex_important = "Flexibility to choose location", remote_pos_life = "Remote → positive personal life",
           prefer_remote = "Prefer remote over office", career_neg = "Remote → career negative",
           wlb_difficult = "WLB difficult remotely", more_challenging = "Remote more challenging",
           less_productive = "Feel less productive")
pr <- rm %>% filter(!is.na(band6)) %>% select(band = band6, all_of(names(items))) %>%
  pivot_longer(-band, names_to = "item", values_to = "v") %>% filter(!is.na(v)) %>%
  group_by(band, item) %>% summarise(mean = round(mean(v), 2), n = n(), .groups = "drop") %>%
  mutate(label = unname(items[item]))
write_json(pr, file.path(OUT, "rmap_remote.json"), auto_unbox = TRUE)

# 5) commute: observed one-way minutes and weekly hours avoided, by band
cm <- rm %>% filter(!is.na(band6), !is.na(commute_min)) %>% group_by(band = band6) %>%
  summarise(commute_median = median(commute_min), commute_mean = round(mean(commute_min), 1),
            saved_mean = round(mean(hours_saved), 2), saved_median = round(median(hours_saved), 2),
            n = n(), .groups = "drop") %>%
  mutate(band = factor(band, band6_levels)) %>% arrange(band) %>% mutate(band = as.character(band))
write_json(cm, file.path(OUT, "commute_by_remote.json"), auto_unbox = TRUE)
cat("\nCommute by band:\n"); print(cm)

# 6) repair arrow-encoding in the existing perception label files
for (f in c("rmap_overall", "rmap_sector", "rmap_country", "rmap_gender")) {
  p <- file.path(OUT, paste0(f, ".json")); d <- fromJSON(p)
  if ("item" %in% names(d)) d$label <- unname(items[d$item])
  write_json(d, p, auto_unbox = TRUE)
}
cat("\nlabels repaired\n")
