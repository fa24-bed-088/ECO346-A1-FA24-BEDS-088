# 01_default.R -- Question 4: R's default figure, nothing added.
# literate (0/1) against age for the literacy sample, saved untouched as SVG.
source("scripts/00_helpers.R")

lit <- literacy_sample()

p <- ggplot(lit, aes(age, literate)) + geom_point()

ggsave("figures/default.svg", p, width = 7, height = 4.5)
cat("Saved figures/default.svg  (", nrow(lit), "persons )\n")
