"""04_second_language.py -- Question 5: recompute the Question 3 band table in Python
and redraw the figure.  Run from the repository root:  python scripts/04_second_language.py

Variant 0 (FA24-BEDS-088: 88 = 11 x 8 + 0) -> Punjab rural (prov_code 2, urban_rural 1).
Needs: pandas, numpy, matplotlib.  Run scripts/03_literacy.R first (it writes the R table).
"""
import os

import matplotlib
matplotlib.use("Agg")                 # draw to files, no window
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

PROV_CODE, URBAN_RURAL = 2, 1
os.makedirs("figures", exist_ok=True)
os.makedirs("tables", exist_ok=True)

# ---- Data: person file + (hhweight, prov_code, urban_rural) from the household file ----
person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv",
                 usecols=["hhid", "hhweight", "prov_code", "urban_rural"])
df = person.merge(hh, on="hhid", how="left")
df = df[(df.prov_code == PROV_CODE) & (df.urban_rural == URBAN_RURAL)]

# Literacy sample: aged 10-64, literate not missing
lit = df[(df.age >= 10) & (df.age <= 64) & df.literate.notna()].copy()

# ---- Five-year bands, plotted at midpoints ----
lit["band_lo"] = 10 + 5 * ((lit.age - 10) // 5)
lit["band"] = lit.band_lo.astype(int).astype(str) + "–" + (lit.band_lo + 4).astype(int).astype(str)
lit["mid"] = lit.band_lo + 2
lit["sex_lab"] = np.where(lit.sex == 2, "Women", "Men")


lit["wx"] = lit.hhweight * lit.literate          # w_i * x_i
cells = (lit.groupby(["band_lo", "band", "mid", "sex_lab"])
            .agg(n=("literate", "size"), sw=("hhweight", "sum"), swx=("wx", "sum"))
            .reset_index())
cells["rate"] = 100 * cells.swx / cells.sw        # weighted mean, as a percentage
cells["thin"] = cells.n < 30            # thin cell -> hollow marker

# Wide band table: band, then persons and weighted rate for each sex
wide = cells.pivot(index=["band_lo", "band"], columns="sex_lab", values=["n", "rate"])
table = pd.DataFrame({
    "band": wide.index.get_level_values("band"),
    "n_women": wide[("n", "Women")].astype(int).values,
    "rate_women": wide[("rate", "Women")].round(1).values,
    "n_men": wide[("n", "Men")].astype(int).values,
    "rate_men": wide[("rate", "Men")].round(1).values,
})
table["gap_pts"] = (table.rate_men - table.rate_women).round(1)
table.to_csv("tables/band_table_python.csv", index=False)
print(table.to_string(index=False))

# ---- Agreement with the R table (must match to one decimal) ----
if not os.path.exists("tables/band_table_R.csv"):
    raise SystemExit("Run scripts/03_literacy.R first: it writes tables/band_table_R.csv")
r_table = pd.read_csv("tables/band_table_R.csv")
assert list(r_table.band) == list(table.band), "band labels differ"
assert (r_table.n_women.values == table.n_women.values).all(), "women counts differ"
assert (r_table.n_men.values == table.n_men.values).all(), "men counts differ"
assert np.allclose(r_table.rate_women, table.rate_women, atol=0.05), "women rates differ"
assert np.allclose(r_table.rate_men, table.rate_men, atol=0.05), "men rates differ"
w1519 = table.loc[table.band == "15–19", "rate_women"].item()
w1519_r = r_table.loc[r_table.band == "15–19", "rate_women"].item()
print(f"\nWomen 15-19 literacy: R = {w1519_r:.1f}, Python = {w1519:.1f}  -> tables agree")

# ---- Figure (matplotlib defaults changed to match the ggplot figure) ----
COL = {"Women": "#D55E00", "Men": "#0072B2"}
fig, ax = plt.subplots(figsize=(9.5, 5.8))

for sex in ["Men", "Women"]:
    d = cells[cells.sex_lab == sex].sort_values("mid")
    ax.plot(d.mid, d.rate, color=COL[sex], lw=2)
    # hollow marker (white face) for thin cells, filled otherwise
    ax.scatter(d.mid, d.rate, s=60, linewidths=1.6, zorder=3, edgecolors=COL[sex],
               facecolors=[("white" if t else COL[sex]) for t in d.thin])
    ax.text(d.mid.max() + 1.2, d.rate.iloc[-1], sex, color=COL[sex],
            fontweight="bold", fontsize=12, va="center")        # direct label, no legend

# Annotate the band with the largest gap
g = cells.pivot(index="mid", columns="sex_lab", values="rate")
g["gap"] = g.Men - g.Women
gx = g.gap.abs().idxmax()
men_v, women_v = g.loc[gx, "Men"], g.loc[gx, "Women"]
band_lab = cells.loc[cells.mid == gx, "band"].iloc[0]
ax.plot([gx, gx], [women_v, men_v], color="0.25", lw=1.2)
ax.text(gx - 0.9, (men_v + women_v) / 2 + 5,
        f"Largest gap,\nages {band_lab}:\nmen {men_v:.1f}%,\nwomen {women_v:.1f}%\n({abs(men_v - women_v):.1f} points)",
        ha="right", va="center", fontsize=10, color="0.1", linespacing=1.15)

# matplotlib defaults changed so the figure matches the R one:
ax.set_ylim(0, 100)                                       # default would autoscale
ax.set_yticks(range(0, 101, 20))
ax.set_yticklabels([f"{v}%" for v in range(0, 101, 20)])
ax.set_xticks(sorted(cells.mid.unique()))
ax.set_xticklabels(cells.drop_duplicates("mid").sort_values("mid").band)
ax.margins(x=0.03)
for side in ["top", "right", "left", "bottom"]:          # default draws a box of 4 spines
    ax.spines[side].set_visible(False)
ax.grid(axis="y", color="0.9", lw=1)                      # default has no grid
ax.set_axisbelow(True)
ax.tick_params(length=0)
ax.set_xlabel("Age band (plotted at band midpoint)", fontsize=12)
ax.set_ylabel("Weighted literacy rate", fontsize=12)
ax.set_title(f"In rural Punjab, men out-read women at every age; the gap peaks at "
             f"{abs(men_v - women_v):.0f} points among ages {band_lab}",
             loc="left", fontweight="bold", fontsize=12)
fig.text(0.01, 0.01,
         "Source: PSLM 2019–20 person file, household weights and area from the household file.\n"
         f"Sample: persons aged 10–64 with non-missing literacy in Punjab rural (N = {len(lit):,}). Weighting: hhweight.\n"
         "Hollow markers: thin cells, fewer than 30 unweighted observations in that band for that sex.",
         fontsize=8.5, color="0.3", ha="left", va="bottom")
fig.subplots_adjust(left=0.08, right=0.92, top=0.92, bottom=0.2)

plt.rcParams["svg.hashsalt"] = "eco346"      # makes the SVG byte-identical on every run
plt.savefig("figures/literacy_by_age_python.svg", metadata={"Date": None})
print("Saved figures/literacy_by_age_python.svg")
