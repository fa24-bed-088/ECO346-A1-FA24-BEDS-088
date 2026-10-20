# 00_helpers.R -- shared helpers, sourced by scripts 01-03.
# Run every script from the repository root:  Rscript scripts/01_default.R
#
# Variant 0 (reg. no. FA24-BEDS-088: 88 = 11 x 8 + 0)  ->  Punjab rural
#   prov_code 2 = Punjab, urban_rural 1 = rural

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

# Make sure en dashes etc. survive on machines whose default locale is not UTF-8
# (ignored harmlessly if the locale is not available, e.g. on Windows).
suppressWarnings(try(Sys.setlocale("LC_CTYPE", "C.UTF-8"), silent = TRUE))

PROV_CODE   <- 2   # Punjab
URBAN_RURAL <- 1   # rural
VARIANT_LABEL <- "Punjab rural"

dir.create("figures", showWarnings = FALSE)
dir.create("tables",  showWarnings = FALSE)

# ---- Data: person file + (hhweight, prov_code, urban_rural) from household file ----
load_variant <- function() {
  person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
  hh <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE) |>
    select(hhid, hhweight, prov_code, urban_rural)

  person |>
    left_join(hh, by = "hhid") |>                       # attach by household id
    filter(prov_code == PROV_CODE, urban_rural == URBAN_RURAL)  # my variant only
}

# Literacy sample: aged 10-64, literate not missing
literacy_sample <- function() {
  load_variant() |>
    filter(age >= 10, age <= 64, !is.na(literate))
}

# Students: annual education spending greater than zero
student_sample <- function() {
  load_variant() |>
    filter(!is.na(ed_total), ed_total > 0)
}

# ---- Weighted statistics (exactly the definitions in the assignment) ----
weighted_mean <- function(x, w) sum(w * x) / sum(w)

# Sort by x, take cumulative share of weight, return the smallest x whose
# cumulative share reaches or exceeds p.  (Not R's quantile().)
weighted_quantile <- function(x, w, p) {
  o <- order(x)
  x <- x[o]
  w <- w[o]
  cum_share <- cumsum(w) / sum(w)
  x[which(cum_share >= p)[1]]
}

fmt_rs <- function(x) paste0("Rs ", format(round(x), big.mark = ",", trim = TRUE))
