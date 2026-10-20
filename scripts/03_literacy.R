# 03_literacy.R -- Question 3: weighted literacy rate by age band, women vs men.
source("scripts/00_helpers.R")

lit <- literacy_sample()      # aged 10-64, literate not missing

# ---- Five-year age bands: 10-14, 15-19, ..., 60-64 (eleven bands) ----
lit <- lit |>
  mutate(band_lo = 10 + 5 * ((age - 10) %/% 5),
         band    = paste0(band_lo, "\u2013", band_lo + 4),   # label, e.g. "15–19"
         mid     = band_lo + 2,                               # plotted at midpoint
         sex_lab = if_else(sex == 2, "Women", "Men"))

# ---- Band table: persons and weighted literacy rate, by sex ----
cells <- lit |>
  group_by(band_lo, band, mid, sex_lab) |>
  summarise(n    = n(),                                         # unweighted persons
            rate = 100 * weighted_mean(literate, hhweight),     # weighted % literate
            .groups = "drop") |>
  mutate(thin = n < 30)                                         # thin cell: < 30 obs

band_table <- cells |>
  select(band_lo, band, sex_lab, n, rate) |>
  tidyr::pivot_wider(names_from = sex_lab, values_from = c(n, rate)) |>
  transmute(band,
            n_women = n_Women, rate_women = round(rate_Women, 1),
            n_men   = n_Men,   rate_men   = round(rate_Men, 1),
            gap_pts = round(rate_Men - rate_Women, 1)) |>
  # NB: the gap is recomputed on unrounded rates below for choosing the largest
  arrange(band)
write_csv(band_table, "tables/band_table_R.csv")

# Markdown version for the README
md <- c("| Age band | Women: persons | Women: literacy % | Men: persons | Men: literacy % |",
        "|---|---:|---:|---:|---:|",
        sprintf("| %s | %d | %.1f | %d | %.1f |", band_table$band,
                band_table$n_women, band_table$rate_women,
                band_table$n_men, band_table$rate_men))
writeLines(md, "tables/band_table_R.md")
print(as.data.frame(band_table))

# ---- Largest gap between men and women (unrounded rates) ----
gaps <- cells |>
  select(band, mid, sex_lab, rate) |>
  tidyr::pivot_wider(names_from = sex_lab, values_from = rate) |>
  mutate(gap = Men - Women)
top <- gaps |> slice_max(abs(gap), n = 1)

r <- function(b, s) round(cells$rate[cells$band == b & cells$sex_lab == s], 1)
q3 <- tibble(
  statistic = c("women_15_19", "men_15_19", "women_55_59", "men_55_59",
                "largest_gap_band", "largest_gap_points"),
  value = c(r("15\u201319", "Women"), r("15\u201319", "Men"),
            r("55\u201359", "Women"), r("55\u201359", "Men"),
            top$band, round(abs(top$gap), 1))
)
write_csv(q3, "tables/q3_numbers.csv")
print(as.data.frame(q3))

# ---- Figure ----
col_women <- "#D55E00"   # vermilion
col_men   <- "#0072B2"   # blue  (colour-blind safe pair)

plot_df <- cells |>
  mutate(colour = if_else(sex_lab == "Women", col_women, col_men),
         fill   = if_else(thin, "white", colour))   # hollow marker = thin cell

ends <- plot_df |> filter(band_lo == max(band_lo))
x_end <- max(plot_df$mid)

# Annotation for the band with the largest gap
gx  <- top$mid
gy  <- (top$Men + top$Women) / 2

p <- ggplot(plot_df, aes(mid, rate, group = sex_lab)) +
  geom_line(aes(colour = colour), linewidth = 0.9) +
  geom_point(aes(colour = colour, fill = fill), shape = 21, size = 3.2, stroke = 1.1) +
  # gap bracket at the widest band
  annotate("segment", x = gx, xend = gx, y = top$Women, yend = top$Men,
           colour = "grey25", linewidth = 0.5) +
  # text sits to the LEFT of the bracket, in the empty space between the two lines
  annotate("text", x = gx - 0.9, y = gy + 5, hjust = 1, size = 3.6, lineheight = 0.95,
           colour = "grey15",
           label = sprintf("Largest gap,\nages %s:\nmen %.1f%%,\nwomen %.1f%%\n(%.1f points)",
                           top$band, top$Men, top$Women, abs(top$gap))) +
  # direct labels at the right-hand end of each series
  geom_text(data = ends, aes(x = x_end + 1.2, label = sex_lab, colour = colour),
            hjust = 0, fontface = "bold", size = 4.2) +
  scale_colour_identity() +
  scale_fill_identity() +
  scale_x_continuous(breaks = unique(plot_df$mid), labels = unique(plot_df$band)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                     labels = function(v) paste0(v, "%"), expand = c(0, 0)) +
  coord_cartesian(clip = "off") +
  labs(
    title = sprintf("In rural Punjab, men out-read women at every age; the gap peaks at %.0f points among ages %s",
                    abs(top$gap), top$band),
    x = "Age band (plotted at band midpoint)",
    y = "Weighted literacy rate",
    caption = paste0(
      "Source: PSLM 2019\u201320 person file, household weights and area from the household file.\n",
      "Sample: persons aged 10\u201364 with non-missing literacy in ", VARIANT_LABEL,
      " (N = ", format(nrow(lit), big.mark = ","), "). Weighting: hhweight.\n",
      "Hollow markers: thin cells, fewer than 30 unweighted observations in that band for that sex.")
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        plot.title = element_text(face = "bold", size = 12.5),
        plot.title.position = "plot",
        plot.caption = element_text(hjust = 0, size = 8.5, colour = "grey30"),
        plot.caption.position = "plot",
        plot.margin = margin(10, 45, 10, 10))

ggsave("figures/literacy_by_age.svg", p, width = 9.5, height = 5.8)
cat("Saved figures/literacy_by_age.svg\n")
