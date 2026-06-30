# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 09_calibrate_Peru.R
# Description: Calibrate gridded data to station locations.

#
# Author(s): Emily Ball
# Date created: 2026-01-30
# Last updated: 2026-06-02
# Environment: local / hub
# ------------------------------------------------------------------------------

library(devtools)
library(ggplot2)
library(tidyr)
library(dplyr)
library(cowplot)
library(patchwork)

clim4health_path <- "/esarchive/scratch/eball/gitlab_repos/clim4health/"
devtools::load_all(clim4health_path)

####################################################################

station_data <- readRDS("data/raw/Peru/obs/peru.rds")

if (!file.exists("data/raw/Peru/era5land_weekly.rds")) {
  reanalysis <- c4h_load("data/raw/Peru/era5land/",
                         variable = "t2m", ext = "nc",
                         month = 1:12, year = 2023:2025)
  reanalysis$attrs$Variable$metadata <- list(reanalysis$attrs$Variable$metadata,
                                           t2m = "tmp")
  reanalysis <-
    CSTools::CST_Subset(reanalysis, along = "time", indices =
                        which(as.Date(reanalysis$attrs$Dates) <=
                                "2025-06-07" &
                                as.Date(reanalysis$attrs$Dates) >=
                                  "2023-03-26"))
  
  reanalysis_weekly <- c4h_time(reanalysis,
                                dim_aggregation = "time",
                                week_start = "Sunday",
                                time_aggregation = "weekly",
                                fun = "mean")
  
  saveRDS(reanalysis_weekly, paste0("data/raw/Peru/era5land_weekly.rds"))
  rm(reanalysis)
} else {
  reanalysis_weekly <- readRDS("data/raw/Peru/era5land_weekly.rds")
}

reanalysis_weekly$attrs$source_files <- c("data/raw/Peru/era5land/era5land_t2m_202301.nc")

reanalysis_weekly <- c4h_convert_units(reanalysis_weekly, var = "t2m",
                                       to = "celsius")
# extract reanalysis at station locations #
locations <- list(latitude = station_data$coords$latitude,
                  longitude = station_data$coords$longitude)

station_temp <- station_data
station_temp$data <- station_data$data[, 2, , , , , drop = FALSE]
station_temp$attrs$Variable$varName <- station_temp$attrs$Variable$varName[2]
station_temp$dims <- dim(station_temp$data)

cal_data <- c4h_downscale("Interpolation",
                          exp = reanalysis_weekly,
                          obs = station_temp,
                          points = locations,
                          method_point_interp = "9point")

ts_cal <- drop(cal_data$exp$data)
st_cal <- drop(station_temp$data)

st_cal <- data.frame(st_cal)
names(st_cal) <- paste(station_data$attrs$Variable$metadata$location)
st_cal$date <- as.Date(station_data$attrs$Dates[1, ])
st_cal$source <- "station"
st_cal <- st_cal %>%
  pivot_longer(cols = -c(date, source), names_to = "station",
               values_to = "temp")

ts_cal <- data.frame(ts_cal)
names(ts_cal) <- paste(station_data$attrs$Variable$metadata$location)
ts_cal$date <- as.Date(cal_data$exp$attrs$Dates[1, ])
ts_cal$source <- "reanalysis"
ts_cal <- ts_cal %>%
  pivot_longer(cols = -c(date, source), names_to = "station",
               values_to = "temp")


data_long <- rbind(st_cal, ts_cal)

p1 <- ggplot(data_long, aes(x = date, y = temp, color = source,
                            linetype = source)) +
  geom_line() +
  facet_wrap(~ station) +
  theme_bw() +
  labs(x = "Date", y = "Temperature (°C)", color = "Data Source",
       linetype = "Data Source") +
  theme(legend.position = "bottom")

ggsave("figures/Peru/calibration_plot.png", p1,
       width = 10, height = 6)


rmse <- (station_temp$data - cal_data$exp$data)^2

rmse <- sqrt(apply(rmse, c(6), mean, na.rm = TRUE))

correlation <- apply(drop(station_temp$data), c(2), function(x) {
  cor(x, drop(cal_data$exp$data), use = "complete.obs")})
corr <- c()

for (i in 1:6) {
  corr[i] <- correlation[i, i]
}

temp_cal <- cal_data$exp
temp_cal <- CSTools::CST_ChangeDimNames(temp_cal, original_names = c("sdate", "time"),
                                        new_names = c("stime", "date"))
temp_cal <- CSTools::CST_ChangeDimNames(temp_cal, original_names = c("date", "stime"),
                                        new_names = c("sdate", "time"))
temp_cal <- CSTools::CST_ReorderDims(temp_cal, names(dim(cal_data$exp$data)))

temp_stat <- station_temp
temp_stat <- CSTools::CST_ChangeDimNames(temp_stat, original_names = c("sdate", "time"),
                                         new_names = c("stime", "date"))
temp_stat <- CSTools::CST_ChangeDimNames(temp_stat, original_names = c("date", "stime"),
                                         new_names = c("sdate", "time"))
temp_stat <- CSTools::CST_ReorderDims(temp_stat, names(dim(station_temp$data)))

temp_pp <- c4h_verify(temp_cal, temp_stat, metrics = "RMSE")

p2 <- c4h_plot(temp_pp$RMSE$rmse)

ggsave("figures/Peru/calibration_rmse.png", p2,
       width = 10, height = 6)