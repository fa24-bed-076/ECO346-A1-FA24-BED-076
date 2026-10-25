import pandas as pd
import matplotlib.pyplot as plt

# keep text as real text in the SVG (matplotlib's default turns letters into shapes)
plt.rcParams["svg.fonttype"] = "none"

p  = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")

# attach weight, province and area to each person, keep rural Khyber Pakhtunkhwa
d = p.merge(hh[["hhid", "hhweight", "prov_code", "urban_rural"]], on="hhid", how="inner")
d = d[(d["prov_code"] == 1) & (d["urban_rural"] == 1)]

# literacy sample: age 10-64, literate not missing
lit = d[(d["age"] >= 10) & (d["age"] <= 64) & d["literate"].notna()].copy()

# five-year bands [10,15), [15,20), ... closed on the left, like R's right = FALSE
edges  = list(range(10, 70, 5))
labels = [f"{a}-{a + 4}" for a in range(10, 65, 5)]
lit["band"]  = pd.cut(lit["age"], bins=edges, right=False, labels=labels)
lit["mid"]   = lit["age"].sub(10).floordiv(5).mul(5).add(12)
lit["group"] = lit["sex"].map({1: "Men", 2: "Women"})

# weighted literacy rate and number of persons in each band and sex
lit["wl"] = lit["hhweight"] * lit["literate"]
tab = (lit.groupby(["band", "mid", "group"], observed=True)
          .agg(n=("age", "size"), wl=("wl", "sum"), w=("hhweight", "sum"))
          .reset_index())
tab["rate"] = 100 * tab["wl"] / tab["w"]
tab["thin"] = tab["n"] < 30

out = tab.copy()
out["rate"] = out["rate"].round(1)
print(out[["band", "mid", "group", "n", "rate", "thin"]].to_string(index=False))

# band with the largest gap, on unrounded rates
wide = tab.pivot(index=["band", "mid"], columns="group", values="rate").reset_index()
wide["gap"] = wide["Men"] - wide["Women"]
big = wide.loc[wide["gap"].idxmax()]

colours = {"Women": "#C0392B", "Men": "#1F4E79"}
fig, ax = plt.subplots(figsize=(8, 5))
for grp in ["Women", "Men"]:
    s = tab[tab["group"] == grp].sort_values("mid")
    ax.plot(s["mid"], s["rate"], color=colours[grp])
    solid, thin = s[~s["thin"]], s[s["thin"]]
    ax.scatter(solid["mid"], solid["rate"], color=colours[grp], s=45, zorder=3)
    ax.scatter(thin["mid"], thin["rate"], facecolors="white",
               edgecolors=colours[grp], s=45, linewidths=1.5, zorder=3)
    ax.text(s["mid"].iloc[-1] + 1, s["rate"].iloc[-1], grp,
            color=colours[grp], fontweight="bold", va="center")

ax.plot([big["mid"], big["mid"]], [big["Women"], big["Men"]], color="black")
ax.text(big["mid"] + 0.8, (big["Women"] + big["Men"]) / 2,
        f"Largest gap: {big['gap']:.1f} points\n(ages {big['band']})", va="center")

ax.set_ylim(0, 100)
ax.set_xlim(10, 70)
ax.set_xticks(range(12, 63, 10))
ax.set_xlabel("Age band (plotted at band midpoint)")
ax.set_ylabel("Literacy rate (%)")
ax.set_title("Among rural KP women aged 55-59 only 2.9% are literate, versus 43.0% of men",
             loc="left", fontsize=11)
for side in ["top", "right"]:
    ax.spines[side].set_visible(False)
fig.text(0.01, 0.01,
         "Source: PSLM 2019-20 person file. Sample: persons aged 10-64, rural Khyber Pakhtunkhwa,\n"
         "literate not missing. Weighted by hhweight. Hollow markers = fewer than 30 observations.",
         fontsize=8, ha="left", va="bottom")
fig.subplots_adjust(bottom=0.2)
plt.savefig("figures/literacy_python.svg")
