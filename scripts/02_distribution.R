# 02_distribution.R -- Question 2: weighted histogram of education spending (log scale).
source("scripts/00_helpers.R")

st <- student_sample()          # students: ed_total > 0
x  <- st$ed_total
w  <- st$hhweight

# ---- Statistics (all students with ed_total > 0) ----
n_students   <- nrow(st)
med_w        <- weighted_quantile(x, w, 0.50)
med_unw      <- median(x)
p10          <- weighted_quantile(x, w, 0.10)
p90          <- weighted_quantile(x, w, 0.90)
ratio_90_10  <- p90 / p10

# ---- Histogram range: log10 from 2.0 to 6.0 (Rs 100 to Rs 1,000,000) ----
in_range   <- x >= 100 & x <= 1e6
n_excluded <- sum(!in_range)
xr <- x[in_range]
wr <- w[in_range]

# Bin index 0..39, each 0.1 wide in log10 units. The 1e-9 guards against
# floating-point error exactly at a power of ten; Rs 1,000,000 goes in the last bin.
bin <- pmin(floor((log10(xr) - 2) * 10 + 1e-9), 39)

hist_df <- tibble(bin = bin, w = wr) |>
  group_by(bin) |>
  summarise(weight = sum(w), .groups = "drop") |>
  right_join(tibble(bin = 0:39), by = "bin") |>      # keep empty bins as zero
  mutate(weight = coalesce(weight, 0),
         left   = 2 + bin / 10,
         mid    = left + 0.05,
         # density per log10 unit: share of weight in bin / bin width (0.1)
         density = weight / sum(wr) / 0.1)

# ---- Numbers for the report / Google Form ----
nums <- tibble(
  statistic = c("n_students", "weighted_median", "unweighted_median",
                "weighted_p10", "weighted_p90", "ratio_p90_p10", "n_excluded"),
  value = c(n_students, round(med_w), round(med_unw),
            round(p10), round(p90), round(ratio_90_10, 2), n_excluded)
)
write_csv(nums, "tables/q2_numbers.csv")
print(as.data.frame(nums))
cat(sprintf("\nRatio p90/p10 to two decimals: %.2f\n", ratio_90_10))

# ---- Figure ----
rs_breaks <- 2:6
rs_labels <- c("Rs 100", "Rs 1,000", "Rs 10,000", "Rs 100,000", "Rs 1,000,000")

ymax <- max(hist_df$density)

p <- ggplot(hist_df, aes(x = mid, y = density)) +
  geom_col(width = 0.1, fill = "#4C78A8", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = log10(c(med_w, p90)), linetype = "dashed",
             colour = "grey20", linewidth = 0.5) +
  annotate("text", x = log10(med_w) - 0.04, y = ymax * 1.16, hjust = 1,
           label = paste0("Weighted median\n", fmt_rs(med_w)),
           size = 3.6, lineheight = 0.95) +
  annotate("text", x = log10(p90) + 0.04, y = ymax * 1.16, hjust = 0,
           label = paste0("Weighted 90th percentile\n", fmt_rs(p90)),
           size = 3.6, lineheight = 0.95) +
  scale_x_continuous(breaks = rs_breaks, labels = rs_labels) +
  coord_cartesian(xlim = c(2, 6)) +    # zoom, don't drop bars at the edges
  scale_y_continuous(expand = expansion(mult = c(0, 0.28))) +
  labs(
    title = paste0("Typical rural Punjab student: ", fmt_rs(med_w),
                   " a year, but the top tenth spend ", format(round(ratio_90_10, 1), nsmall = 1),
                   " times the bottom tenth's level"),
    x = "Annual education spending per student (log scale)",
    y = "Density per log10 unit",
    caption = paste0(
      "Source: PSLM 2019–20 person file, household weights and area from the household file.\n",
      "Sample: students with ed_total > 0 in ", VARIANT_LABEL, " (N = ",
      format(n_students, big.mark = ","), "); ", n_excluded,
      " students outside Rs 100–Rs 1,000,000 are excluded from the bars.\n",
      "Weighting: every bar, median and percentile is weighted by hhweight; bins are 0.1 wide in log10 units.")
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        plot.title = element_text(face = "bold", size = 12.5),
        plot.title.position = "plot",
        plot.caption = element_text(hjust = 0, size = 8.5, colour = "grey30"),
        plot.caption.position = "plot")

ggsave("figures/distribution.svg", p, width = 9, height = 5.5)
cat("Saved figures/distribution.svg\n")

# For my own check: statistics using only the in-range students
cat("\n[check] in-range students only: n =", length(xr),
    " weighted median =", weighted_quantile(xr, wr, .5),
    " p10 =", weighted_quantile(xr, wr, .1),
    " p90 =", weighted_quantile(xr, wr, .9), "\n")
