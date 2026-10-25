library(tidyverse)

p <- read_csv("data/pslm_person_subset.csv")
hh <- read_csv("data/pslm_hh_subset.csv")

d <- p |>
  inner_join(hh |> select(hhid, hhweight, prov_code, urban_rural), by = "hhid") |>
  filter(prov_code == 1, urban_rural == 1)
rm(p, hh)

#literacy sample: age 10-64, literate not missing
lit <- d |> filter(age>=10, age<=64, !is.na(literate))

# five-year age bands, plotted at their midpoints
lit <- lit |>
  mutate(band  = cut(age, breaks = seq(10, 65, by = 5), right = FALSE,
                     labels = paste0(seq(10, 60, 5), "-", seq(14, 64, 5))),
         mid   = 12 + 5 * (as.integer(band) - 1),
         group = if_else(sex == 1, "Men", "Women"))

#band table: persons and weighted literacy rate for each sex
tab <- lit |>
  group_by(band, mid, group) |>
  summarise(n    = n(),
            rate = 100 * sum(hhweight * literate) / sum(hhweight),
            .groups = "drop") |>
  mutate(thin = n < 30)

print(tab |> mutate(rate = round(rate, 1)), n = Inf)

# band with the largest gap, found on unrounded rates
wide <- tab |>
  select(band, mid, group, rate) |>
  pivot_wider(names_from = group, values_from = rate) |>
  mutate(gap = Men - Women)
big <- wide |> slice_max(gap, n = 1)

g <- ggplot(tab, aes(mid, rate, colour = group, group = group)) +
  geom_line() +
  geom_point(data = filter(tab, !thin), size = 3) +
  geom_point(data = filter(tab, thin), shape = 21, fill = "white",
             size = 3, stroke = 1.2) +
  geom_text(data = filter(tab, mid == 62), aes(label = group),
            hjust = -0.3, fontface = "bold") +
  annotate("segment", x = big$mid, xend = big$mid,
           y = big$Women, yend = big$Men, colour = "black") +
  annotate("text", x = big$mid, y = (big$Women + big$Men) / 2,
           label = paste0("Largest gap: ", round(big$gap, 1),
                          " points\n(ages ", big$band, ")"),
           hjust = -0.1) +
  scale_colour_manual(values = c(Women = "#C0392B", Men = "#1F4E79")) +
  scale_x_continuous(breaks = seq(12, 62, 10),
                     expand = expansion(mult = c(0.03, 0.15))) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(title = "Among rural KP women aged 55-59 only 2.9% are literate, versus 43.0% of men",
       x = "Age band (plotted at band midpoint)",
       y = "Literacy rate (%)",
       caption = str_wrap("Source: PSLM 2019-20 person file. Sample: persons aged 10-64, rural Khyber Pakhtunkhwa, literate not missing. Weighted by hhweight. Hollow markers = fewer than 30 observations.", width = 100)) +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title.position = "plot",
        plot.caption.position = "plot",
        plot.caption = element_text(hjust = 0))

ggsave("figures/literacy.svg", g, width = 8, height = 5)






