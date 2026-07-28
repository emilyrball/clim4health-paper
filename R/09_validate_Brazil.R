# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 09_calibrate_Brazil.R
# Description: Calibrate gridded data to station locations.

#
# Author(s): Emily Ball
# Date created: 2026-07-20
# Last updated: 2026-07-20
# Environment: local / hub
# ------------------------------------------------------------------------------

library(devtools)
library(ggplot2)
library(tidyr)
library(dplyr)
library(cowplot)
library(patchwork)

clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
rean_path <- "/data/raw/Brazil/era5land/"

devtools::load_all(clim4health_path)

####################################################################

station_data <- readRDS("data/processed/Brazil/obs/brazil.rds")
station_data <- c4h_time(station_data, dim_aggregation = "time",
                         time_aggregation = "monthly",
                         fun = "mean")

reanalysis_monthly <- c4h_load(rean_path,
                 variable = "t2m",
                 year = 2000:2025,
                 month = 1,
                 leadtime_month = 1:12,
                 bbox = c(-5, -40, -10, -35),
                 ext = "nc")

#reanalysis_monthly <- c4h_time(reanalysis_monthly, dim_aggregation = "time",
#                         time_aggregation = "monthly",
#                         fun = "mean")
                 
reanalysis_monthly <- c4h_convert_units(reanalysis_monthly, var = "t2m",
                                       to = "celsius")
# extract reanalysis at station locations #
locations <- list(latitude = station_data$attrs$location$latitude,
                  longitude = station_data$attrs$location$longitude)

# select var = temp_mean
station_temp <- station_data
station_temp$data <- station_data$data[, 2, , , , , drop = FALSE]
station_temp$attrs$Variable$varName <- station_temp$attrs$Variable$varName[2]
station_temp$dims <- dim(station_temp$data)

cal_data <- c4h_downscale("Interpolation",
                          exp = reanalysis_monthly,
                          obs = station_temp,
                          points = locations,
                          method_point_interp = "9point")
cal_data$exp$coords$location <- 1
cal_data$exp$coords$latitude <- NULL
cal_data$exp$coords$longitude <- NULL
ts_cal <- c4h_convert(cal_data$exp, "data.frame", drop = TRUE)
st_cal <- c4h_convert(station_temp, "data.frame", drop = TRUE)


st_cal$source <- "station"
ts_cal$source <- "reanalysis"

data_long <- rbind(st_cal, ts_cal) %>%
  select(-c(sdate, time, location, latitude, longitude))

p1 <- ggplot(data_long, aes(x = as.Date(date), y = value, color = source,
                            linetype = source)) +
  geom_line() +
  theme_minimal() +
  labs(x = "Date", y = "Temperature (°C)", color = "Data Source",
       linetype = "Data Source") +
  theme(legend.position = "bottom")

ggsave("figures/Brazil/calibration_plot.png", p1,
       width = 14, height = 5, dpi = 300)
ggsave("figures/Brazil/calibration_plot.pdf", p1,
       device = grDevices::cairo_pdf,
       width = 14, height = 5, dpi = 300)

data_wide <- data_long %>%
  mutate(date = paste0(lubridate::year(as.Date(date)), "-", lubridate::month(as.Date(date)))) %>%
  pivot_wider(names_from = source, values_from = value)

data_wide <- data_wide %>%
  summarise(rmse = sqrt(mean((station - reanalysis)^2, na.rm = TRUE)),
         bias = mean(reanalysis - station, na.rm = TRUE),
         corr = cor(station, reanalysis, method = "spearman",
                    use = "pairwise.complete.obs"))

