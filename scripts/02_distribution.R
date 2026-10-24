library(tidyverse)

p <- read_csv("data/pslm_person_subset.csv")
hh <- read_csv("data/pslm_hh_subset.csv")

d <- p |>
  inner_join(hh |> select(hhid, hhweight, prov_code, urban_rural), by = "hhid") |>
  filter(prov_code == 1, urban_rural == 1)

rm(p, hh)
#students: people with education spending above zero
st <- d |> filter(ed_total > 0)

# weighted quantile exactly as the assignment defines it
wq <- function(x, w, p) {
  o  <- order(x)          
  x  <- x[o]
  w  <- w[o]
  cw <- cumsum(w) / sum(w)   
  x[which(cw >= p)[1]]       
}

N <- nrow(st)
w_med <- wq(st$ed_total, st$hhweight, 0.5)
u_med <- median(st$ed_total)
p10 <- wq(st$ed_total, st$hhweight, 0.1)
p90 <- wq(st$ed_total, st$hhweight, 0.9)
ratio <- p90 / p10

lx    <- log10(st$ed_total)
excluded <- sum(lx < 2 | lx > 6)

print(c(N = N, w_med = round(w_med), u_med = round(u_med),
        p10 = round(p10), p90 = round(p90),
        ratio = round(ratio, 2), excluded = excluded))

# students inside the plotted range (Rs 100 to Rs 1,000,000)
sh <- st |>
  mutate(lx = log10(ed_total)) |>
  filter(lx >= 2, lx <= 6)

fmt <- function(x) format(round(x), big.mark = ",")

g <- ggplot(sh, aes(x = lx, weight = hhweight)) +
  geom_histogram(aes(y = after_stat(density)),
                 breaks = seq(2, 6, by = 0.1),
                 fill = "grey60", colour = "white") +
  geom_vline(xintercept = log10(w_med), linetype = "dashed") +
  geom_vline(xintercept = log10(p90),   linetype = "dashed") +
  annotate("text", x = log10(w_med), y = Inf, vjust = 2, hjust = 1.1,
           label = paste0("Median: Rs ", fmt(w_med))) +
  annotate("text", x = log10(p90), y = Inf, vjust = 2, hjust = -0.1,
           label = paste0("90th percentile: Rs ", fmt(p90))) +
  scale_x_continuous(breaks = 2:6,
                     labels = c("Rs 100", "Rs 1,000", "Rs 10,000",
                                "Rs 100,000", "Rs 1,000,000")) +
  labs(title = "Typical rural KP student: Rs 7,000 a year; top 10% spend Rs 25,000+",
       x = "Annual education spending per student (log scale)",
       y = "Density per log10 unit",
       caption = str_wrap(paste0("Source: PSLM 2019-20 person file. Sample: students (ed_total > 0), ",
                                 "rural Khyber Pakhtunkhwa, N = ", fmt(N), "; ", excluded,
                                 " outside Rs 100 to Rs 1,000,000 excluded. Weighted by hhweight."),
                          width = 100)) +
  theme_minimal() +
  theme(plot.title.position = "plot",
        plot.caption.position = "plot",
        plot.caption = element_text(hjust = 0))

ggsave("figures/distribution.svg", g, width = 8, height = 5)
