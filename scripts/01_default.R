library(tidyverse)

p <- read_csv("data/pslm_person_subset.csv")
hh <- read_csv("data/pslm_hh_subset.csv")

d <- p |>
  inner_join(hh |> select(hhid, hhweight, prov_code, urban_rural), by = "hhid") |>
  filter(prov_code == 1, urban_rural == 1)

lit <- d |> filter(age>=10, age<=64, !is.na(literate))

g <- ggplot(lit, aes(age, literate)) + geom_point()
ggsave("figures/default.svg", g)
