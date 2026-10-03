invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))
RAW_DIR <- Sys.getenv("RAW_DIR", "raw_data")   # folder holding the original data files
# Productivity (P), well-being (W) and exploratory composite (C) indices by WFH intensity
# Same components as D2 §5.4, but normalised on the ACTUAL coding of each file:
#   EWCTS 2021: wlb items 1=Never..5=Always (higher = worse)   -> invert: (5-x)/4*100
#               engagement_index is a 1-5 mean (not 0-100)      -> (x-1)/4*100
#               loc_home 1=Never..5=Always
#   EWCS 2024:  stress/wlb items 1=Always..5=Never (higher = better) -> no inversion: (x-1)/4*100
#               loc_home 1=Always..5=Never                        -> reversed to 1=Never..5=Always
# Every component therefore reads "higher = better" on a true 0-100 scale.
suppressPackageStartupMessages({ library(haven); library(dplyr); library(jsonlite) })
OUT <- "data"
clean <- function(x) { x <- as.numeric(x); x[x < 0] <- NA; x }
WFH <- c("Never", "Rarely", "Sometimes", "Often", "Always")

wci <- function(y, w) {                      # weighted mean with 95% CI (Kish effective n)
  ok <- !is.na(y) & !is.na(w); y <- y[ok]; w <- w[ok]
  m <- sum(w * y) / sum(w); v <- sum(w * (y - m)^2) / sum(w)
  neff <- sum(w)^2 / sum(w^2); se <- sqrt(v / neff)
  c(mean = m, lo = m - 1.96 * se, hi = m + 1.96 * se, n = length(y))
}
summarise_idx <- function(df, wave) {
  bind_rows(lapply(c("P", "W", "C"), function(ix)
    bind_rows(lapply(1:5, function(k) {
      s <- df %>% filter(wfh == k)
      r <- wci(s[[ix]], s$wt)
      tibble(wave = wave, wfh = WFH[k], index = ix, mean = round(r[["mean"]], 1),
             lo = round(r[["lo"]], 1), hi = round(r[["hi"]], 1), n = r[["n"]])
    }))))
}
zb <- function(y, x) { ok <- !is.na(y) & !is.na(x); round(unname(coef(lm(scale(y[ok]) ~ scale(x[ok])))[2]), 3) }

# ---------- EWCTS 2021 ----------
e21 <- read_sav(file.path(RAW_DIR, "ewcts_2021_isco2_nace2_nuts2.sav"))
d21 <- tibble(
  wfh = clean(e21$loc_home), wt = clean(e21$weight_core),
  eng = clean(e21$engagement_index), worry = clean(e21$wlb_worry), conc = clean(e21$wlb_concentration),
  W = clean(e21$wellbeing_index)
) %>% mutate(
  P = rowMeans(cbind((eng - 1) / 4 * 100, (5 - worry) / 4 * 100, (5 - conc) / 4 * 100), na.rm = TRUE),
  P = ifelse(is.nan(P), NA, P),
  C = (P + W) / 2
) %>% filter(!is.na(wfh))

# ---------- EWCS 2024 ----------
e24 <- read_sav(file.path(RAW_DIR, "ewcs24_dataset_ukds.sav"), encoding = "latin1")
d24 <- tibble(
  wfh = 6 - clean(e24$loc_home), wt = clean(e24$calweight),
  stress = clean(e24$stress), worry = clean(e24$wlb_worry), tired = clean(e24$wlb_tired),
  W = clean(e24$wellbeing)
) %>% mutate(
  P = rowMeans(cbind((stress - 1) / 4 * 100, (worry - 1) / 4 * 100, (tired - 1) / 4 * 100), na.rm = TRUE),
  P = ifelse(is.nan(P), NA, P),
  C = (P + W) / 2
) %>% filter(!is.na(wfh))

stopifnot(all(range(d21$P, na.rm = TRUE) >= 0 & range(d21$P, na.rm = TRUE) <= 100),
          all(range(d24$P, na.rm = TRUE) >= 0 & range(d24$P, na.rm = TRUE) <= 100))

ef <- bind_rows(summarise_idx(d21, "2021"), summarise_idx(d24, "2024"))
write_json(ef, file.path(OUT, "idx_eurofound.json"), auto_unbox = TRUE)
print(ef, n = 40)

# ---------- R-MAP: add composite to the band file written by rmap_fix.R ----------
rb <- fromJSON(file.path(OUT, "rmap_index_band.json"))
rb$index <- ifelse(rb$index == "P_rmap", "P", ifelse(rb$index == "W_rmap", "W", rb$index))
write_json(rb, file.path(OUT, "rmap_index_band.json"), auto_unbox = TRUE)

# ---------- sanity: standardized slopes (unweighted, as in the paper) ----------
cat("\nStandardized beta (unweighted) of index on WFH level 1-5:\n")
cat("  2021  P:", zb(d21$P, d21$wfh), "  W:", zb(d21$W, d21$wfh), "\n")
cat("  2024  P:", zb(d24$P, d24$wfh), "  W:", zb(d24$W, d24$wfh), "\n")
cat("  P range 2021:", round(range(d21$P, na.rm = TRUE), 1), " | 2024:", round(range(d24$P, na.rm = TRUE), 1), "\n")
cat("  n P 2021:", sum(!is.na(d21$P)), " n P 2024:", sum(!is.na(d24$P)), "\n")
