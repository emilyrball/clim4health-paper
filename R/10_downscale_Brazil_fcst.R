# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 10_downscale_Brazil_fcst.R
# Description: Downscale gridded forecast data to station locations.

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
library(tibble)

# 0. Set paths and load packages
clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
hind_path <- "data/raw/Brazil/fcst/"
rean_path <- "data/raw/Brazil/era5land/"

devtools::load_all(clim4health_path)


# 1. Load data

## Load station data (processed in R/08_station_to_s2dv_Brazil.R)
station_data <- readRDS("data/processed/Brazil/obs/brazil_monthly.rds")

## Load hindcast data
hcst <- c4h_load(hind_path,
                 variable = "t2m",
                 year = 2000:2024,
                 month = 1,
                 leadtime_month = 1:7,
                 bbox = c(-5, -40, -10, -35),
                 ext = "nc")
hcst$attrs$Dates <- as.Date(hcst$attrs$Dates)

## Load forecast data
fcst <- c4h_load(hind_path,
                 variable = "t2m",
                 year = 2025,
                 month = 1,
                 leadtime_month = 1:7,
                 bbox = c(-5, -40, -10, -35),
                 ext = "nc")
fcst$attrs$Dates <- as.Date(fcst$attrs$Dates)

## Load reanalysis data
rean <- c4h_load(rean_path,
                 variable = "t2m",
                 year = 2000:2024,
                 month = 1,
                 leadtime_month = 1:12,
                 bbox = c(-5, -40, -10, -35),
                 ext = "nc")

## Load reanalysis data
obs <- c4h_load(rean_path,
                variable = "t2m",
                year = 2025,
                month = 1,
                leadtime_month = 1:7,
                bbox = c(-5, -40, -10, -35),
                ext = "nc")

# 2. Convert units to Celsius
hcst <- c4h_convert_units(hcst, var = "t2m", to = "celsius")
rean <- c4h_convert_units(rean, var = "t2m", to = "celsius")
fcst <- c4h_convert_units(fcst, var = "t2m", to = "celsius")
obs  <- c4h_convert_units(obs,  var = "t2m", to = "celsius")

# 3. Extract station locations for downscaling
locations <- list(latitude = station_data$attrs$location$latitude,
                  longitude = station_data$attrs$location$longitude)

# 4. Select var = temp_mean and subset for forecast calibration
station_temp <- station_data
station_temp$data <- station_data$data[, 3, , , , , drop = FALSE]
station_temp$attrs$Variable$varName <- station_temp$attrs$Variable$varName[2]
station_temp$dims <- dim(station_temp$data)

# 5. Set coordinates for station data for Intbc downscaling
station_temp$coords$longitude <- locations$longitude
station_temp$coords$latitude <- locations$latitude

## Subset leadtime for forecast calibration
station_fcst <- station_temp
station_fcst$data <- station_fcst$data[, , 1:25, 1:7, , , drop = FALSE]
station_fcst$dims <- dim(station_fcst$data)

# 6. Downscale hindcast and reanalysis data to station locations

## Downscale + calibrate forecast data to station locations
cal_fcst <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hcst,
                          obs = station_fcst,
                          exp_cor = fcst,
                          points = locations,
                          method_point_interp = "9point")
## Downscale hindcast data to station locations
int_fcst <- c4h_downscale("Interpolation",
                          exp = fcst,
                          #obs = station_fcst,
                          points = locations,
                          method_point_interp = "9point")
## Downscale reanalysis data to station locations
int_rean <- c4h_downscale("Interpolation",
                          exp = obs,
                          #obs = station_temp,
                          points = locations,
                          method_point_interp = "9point")
## Downscale + calibrate forecast using reanalysis
rean_tmp <- rean
rean_tmp$data <- rean_tmp$data[, , , 1:7, , , , drop = FALSE]
rean_tmp$dims <- dim(rean_tmp$data)
cal_fcst_by_rean <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hcst,
                          exp_cor = fcst,
                          obs = rean_tmp,
                          points = locations,
                          method_point_interp = "9point")

# 7. Convert downscaled data to data frames for plotting
add_coords <- function(data) {
  data$coords$location  <- 1
  data$coords$latitude  <- NULL
  data$coords$longitude <- NULL
  return(data)
}

cal_fcst$exp <- add_coords(cal_fcst$exp)
int_rean$exp <- add_coords(int_rean$exp)
int_fcst$exp <- add_coords(int_fcst$exp)
cal_fcst_by_rean$exp <- add_coords(cal_fcst_by_rean$exp)


fc_cal <- c4h_convert(cal_fcst$exp, "data.frame", drop = TRUE)
fc_raw <- c4h_convert(int_fcst$exp, "data.frame", drop = TRUE)
rn_raw <- c4h_convert(int_rean$exp, "data.frame", drop = TRUE)
st_raw <- c4h_convert(station_temp, "data.frame", drop = TRUE)
fc_by_rn <- c4h_convert(cal_fcst_by_rean$exp, "data.frame", drop = TRUE)

st_raw$source <- "Station"
st_raw$ensemble <- st_raw$ensemble_value <- 1
fc_cal$source <- "Forecast Calibrated by Station"
fc_raw$source <- "Raw Forecast"
rn_raw$source <- "Reanalysis"
rn_raw$ensemble <- rn_raw$ensemble_value <- 1
fc_by_rn$source <- "Forecast Calibrated by Reanalysis"

source_levels <- c("Station",
                   "Reanalysis",
                   "Raw Forecast",
                   "Forecast Calibrated by Reanalysis",
                   "Forecast Calibrated by Station",
                   "Raw Forecast (mean)",
                   "Forecast Calibrated by Reanalysis (mean)",
                   "Forecast Calibrated by Station (mean)")

data_long <- rbind(st_raw, rn_raw, fc_raw, fc_by_rn, fc_cal) %>%
  as.data.frame() %>%
  select(-c(location, latitude, longitude)) %>%
  mutate(source = factor(source, levels = source_levels)) %>%
  mutate(date = as.Date(date)) %>%
  filter(time <= 7, lubridate::year(date) == 2025)

# ensemble mean for the forecast
ens_mean_long <- data_long %>%
  filter(grepl("Forecast", source)) %>%
  group_by(sdate, date, source) %>%
  summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
  mutate(source = factor(source, levels = source_levels))

ens_range_long <- data_long %>%
  filter(grepl("Forecast", source)) %>%
  group_by(sdate, date, source) %>%
  summarise(ymin = min(value, na.rm = TRUE),
            ymax = max(value, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(source = factor(source, levels = source_levels))

sdate_labels <- data_long %>%
  filter(time == 1) %>%
  distinct(sdate, date) %>%
  arrange(sdate) %>%
  mutate(label = paste0("sdate: ", date)) %>%
  select(sdate, label) %>%
  deframe()  # named vector: names = sdate, values = label

# generate default ggplot hues for the non-black categories, keep them consistent across fill/color
base_colors <- base_colors <- viridisLite::plasma(3, begin = 0.15, end = 0.85)
names(base_colors) <- c("Raw Forecast", "Forecast Calibrated by Reanalysis",
                        "Forecast Calibrated by Station")

color_values <- c(base_colors,
                  "Raw Forecast (mean)" = base_colors[["Raw Forecast"]],
                  "Forecast Calibrated by Reanalysis (mean)" = base_colors[["Forecast Calibrated by Reanalysis"]],
                  "Forecast Calibrated by Station (mean)" = base_colors[["Forecast Calibrated by Station"]],
                  "Reanalysis" = viridisLite::viridis(3)[2],
                  "Station" = "black")

fill_values <- c(base_colors[c("Raw Forecast", "Forecast Calibrated by Reanalysis",
                               "Forecast Calibrated by Station")])

p1 <- ggplot() +
  geom_line(data = filter(data_long, source == "Station"),
            aes(x = date, y = value, color = source), #, linetype = source),
            linewidth = 0.75) +
  geom_ribbon(data = filter(ens_range_long, source == "Raw Forecast"),
              aes(x = date, ymin = ymin, ymax = ymax, fill = source),
              alpha = 0.15) +
  geom_ribbon(data = filter(ens_range_long, source == "Forecast Calibrated by Reanalysis"),
              aes(x = date, ymin = ymin, ymax = ymax, fill = source),
              alpha = 0.15) +
  geom_ribbon(data = filter(ens_range_long, source == "Forecast Calibrated by Station"),
              aes(x = date, ymin = ymin, ymax = ymax, fill = source),
              alpha = 0.15) +
  geom_line(data = ens_mean_long,
            aes(x = date, y = value, color = source), #, linetype = source),
            linewidth = 0.25) +
  geom_line(data = filter(data_long, source == "Reanalysis"),
            aes(x = date, y = value, color = source), #, linetype = source),
            linewidth = 0.75) +
  scale_x_date(date_labels = "%b", date_breaks = "1 month") +
  scale_color_manual(values = color_values,
                     name = "Data Source") +
  scale_fill_manual(values = fill_values, name = "Ensemble range") +
  theme_minimal() +
  labs(x = "Date", y = "Temperature (°C)",
       title = "Forecast Initialization: 01-01-2025") +
  theme(legend.position = "bottom")

ggsave("figures/Brazil/calibrated_plot_fcst_2025.png", p1,
       width = 17, height = 8, dpi = 300)
ggsave("figures/Brazil/calibrated_plot_fcst_2025.jpg", p1,
       width = 17, height = 8, dpi = 300)
ggsave("figures/Brazil/calibrated_plot_fcst_2025.pdf", p1,
       device = grDevices::cairo_pdf,
       width = 17, height = 8, dpi = 300)



# 8. Calculate skill metrics for forecast calibration

## Downscale + calibrate forecast data to station locations
cal_hcst <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hcst,
                          obs = station_fcst,
                          points = locations,
                          method_point_interp = "9point")
## Downscale hindcast data to station locations
int_hcst <- c4h_downscale("Interpolation",
                          exp = hcst,
                          points = locations,
                          method_point_interp = "9point")
## Downscale + calibrate forecast using reanalysis
cal_hcst_by_rean <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hcst,
                          obs = rean_tmp,
                          points = locations,
                          method_point_interp = "9point")

# Calculate skill metrics
skill_cal <- c4h_verify(cal_hcst$exp, cal_hcst$obs,
                        metrics = c("RMSE", "BSS", "RPSS"), na.rm = TRUE)
skill_raw <- c4h_verify(int_hcst$exp, station_fcst,
                        metrics = c("RMSE", "BSS", "RPSS"), na.rm = TRUE)
skill_cal_by_rean <- c4h_verify(cal_hcst_by_rean$exp,
                                station_fcst,
                                metrics = c("RMSE", "BSS", "RPSS"), na.rm = TRUE)

bss10_val_cal <- add_coords(skill_cal$BSS10$bss)
bss10_sig_cal <- add_coords(skill_cal$BSS10$sign)
bss90_val_cal <- add_coords(skill_cal$BSS90$bss)
bss90_sig_cal <- add_coords(skill_cal$BSS90$sign)
rpss_val_cal <- add_coords(skill_cal$RPSS$rpss)
rpss_sig_cal <- add_coords(skill_cal$RPSS$sign)
rmse_val_cal  <- add_coords(skill_cal$RMSE$rmse)
rmse_cfl_cal  <- add_coords(skill_cal$RMSE$conf.lower)
rmse_cfu_cal  <- add_coords(skill_cal$RMSE$conf.upper)

bss10_val_raw <- add_coords(skill_raw$BSS10$bss)
bss10_sig_raw <- add_coords(skill_raw$BSS10$sign)
bss90_val_raw <- add_coords(skill_raw$BSS90$bss)
bss90_sig_raw <- add_coords(skill_raw$BSS90$sign)
rpss_val_raw <- add_coords(skill_raw$RPSS$rpss)
rpss_sig_raw <- add_coords(skill_raw$RPSS$sign)
rmse_val_raw  <- add_coords(skill_raw$RMSE$rmse)
rmse_cfl_raw  <- add_coords(skill_raw$RMSE$conf.lower)
rmse_cfu_raw  <- add_coords(skill_raw$RMSE$conf.upper)

bss10_val_by_rn <- add_coords(skill_cal_by_rean$BSS10$bss)
bss10_sig_by_rn <- add_coords(skill_cal_by_rean$BSS10$sign)
bss90_val_by_rn <- add_coords(skill_cal_by_rean$BSS90$bss)
bss90_sig_by_rn <- add_coords(skill_cal_by_rean$BSS90$sign)
rpss_val_by_rn <- add_coords(skill_cal_by_rean$RPSS$rpss)
rpss_sig_by_rn <- add_coords(skill_cal_by_rean$RPSS$sign)
rmse_val_by_rn  <- add_coords(skill_cal_by_rean$RMSE$rmse)
rmse_cfl_by_rn  <- add_coords(skill_cal_by_rean$RMSE$conf.lower)
rmse_cfu_by_rn  <- add_coords(skill_cal_by_rean$RMSE$conf.upper)

# Convert to data frames for plotting timeseries
bss10_val_cal <- c4h_convert(bss10_val_cal, "data.frame", drop = TRUE)
bss10_val_cal$metric <- "BSS10"
bss10_val_cal$type <- "value"
bss10_val_cal$Source <- "Forecast Calibrated by Station"
bss10_sig_cal <- c4h_convert(bss10_sig_cal, "data.frame", drop = TRUE)
bss10_sig_cal$metric <- "BSS10"
bss10_sig_cal$type <- "significance"
bss10_sig_cal$Source <- "Forecast Calibrated by Station"
bss90_val_cal <- c4h_convert(bss90_val_cal, "data.frame", drop = TRUE)
bss90_val_cal$metric <- "BSS90"
bss90_val_cal$type <- "value"
bss90_val_cal$Source <- "Forecast Calibrated by Station"
bss90_sig_cal <- c4h_convert(bss90_sig_cal, "data.frame", drop = TRUE)
bss90_sig_cal$metric <- "BSS90"
bss90_sig_cal$type <- "significance"
bss90_sig_cal$Source <- "Forecast Calibrated by Station"
rpss_val_cal <- c4h_convert(rpss_val_cal, "data.frame", drop = TRUE)
rpss_val_cal$metric <- "RPSS"
rpss_val_cal$type <- "value"
rpss_val_cal$Source <- "Forecast Calibrated by Station"
rpss_sig_cal <- c4h_convert(rpss_sig_cal, "data.frame", drop = TRUE)
rpss_sig_cal$metric <- "RPSS"
rpss_sig_cal$type <- "significance"
rpss_sig_cal$Source <- "Forecast Calibrated by Station"
rmse_val_cal  <- c4h_convert(rmse_val_cal, "data.frame", drop = TRUE)
rmse_val_cal$metric <- "RMSE"
rmse_val_cal$type <- "value"
rmse_val_cal$Source <- "Forecast Calibrated by Station"
rmse_cfl_cal  <- c4h_convert(rmse_cfl_cal, "data.frame", drop = TRUE)
rmse_cfl_cal$metric <- "RMSE"
rmse_cfl_cal$type <- "conf.lower"
rmse_cfl_cal$Source <- "Forecast Calibrated by Station"
rmse_cfu_cal  <- c4h_convert(rmse_cfu_cal, "data.frame", drop = TRUE)
rmse_cfu_cal$metric <- "RMSE"
rmse_cfu_cal$type <- "conf.upper"
rmse_cfu_cal$Source <- "Forecast Calibrated by Station"

bss10_val_raw <- c4h_convert(bss10_val_raw, "data.frame", drop = TRUE)
bss10_val_raw$metric <- "BSS10"
bss10_val_raw$type <- "value"
bss10_val_raw$Source <- "Raw Forecast"
bss10_sig_raw <- c4h_convert(bss10_sig_raw, "data.frame", drop = TRUE)
bss10_sig_raw$metric <- "BSS10"
bss10_sig_raw$type <- "significance"
bss10_sig_raw$Source <- "Raw Forecast"
bss90_val_raw <- c4h_convert(bss90_val_raw, "data.frame", drop = TRUE)
bss90_val_raw$metric <- "BSS90"
bss90_val_raw$type <- "value"
bss90_val_raw$Source <- "Raw Forecast"
bss90_sig_raw <- c4h_convert(bss90_sig_raw, "data.frame", drop = TRUE)
bss90_sig_raw$metric <- "BSS90"
bss90_sig_raw$type <- "significance"
bss90_sig_raw$Source <- "Raw Forecast"
rpss_val_raw <- c4h_convert(rpss_val_raw, "data.frame", drop = TRUE)
rpss_val_raw$metric <- "RPSS"
rpss_val_raw$type <- "value"
rpss_val_raw$Source <- "Raw Forecast"
rpss_sig_raw <- c4h_convert(rpss_sig_raw, "data.frame", drop = TRUE)
rpss_sig_raw$metric <- "RPSS"
rpss_sig_raw$type <- "significance"
rpss_sig_raw$Source <- "Raw Forecast"
rmse_val_raw  <- c4h_convert( rmse_val_raw, "data.frame", drop = TRUE)
rmse_val_raw$metric <- "RMSE"
rmse_val_raw$type <- "value"
rmse_val_raw$Source <- "Raw Forecast"
rmse_cfl_raw  <- c4h_convert( rmse_cfl_raw, "data.frame", drop = TRUE)
rmse_cfl_raw$metric <- "RMSE"
rmse_cfl_raw$type <- "conf.lower"
rmse_cfl_raw$Source <- "Raw Forecast"
rmse_cfu_raw  <- c4h_convert( rmse_cfu_raw, "data.frame", drop = TRUE)
rmse_cfu_raw$metric <- "RMSE"
rmse_cfu_raw$type <- "conf.upper"
rmse_cfu_raw$Source <- "Raw Forecast"

bss10_val_by_rn <- c4h_convert(bss10_val_by_rn, "data.frame", drop = TRUE)
bss10_val_by_rn$metric <- "BSS10"
bss10_val_by_rn$type <- "value"
bss10_val_by_rn$Source <- "Forecast Calibrated by Reanalysis"
bss10_sig_by_rn <- c4h_convert(bss10_sig_by_rn, "data.frame", drop = TRUE)
bss10_sig_by_rn$metric <- "BSS10"
bss10_sig_by_rn$type <- "significance"
bss10_sig_by_rn$Source <- "Forecast Calibrated by Reanalysis"
bss90_val_by_rn <- c4h_convert(bss90_val_by_rn, "data.frame", drop = TRUE)
bss90_val_by_rn$metric <- "BSS90"
bss90_val_by_rn$type <- "value"
bss90_val_by_rn$Source <- "Forecast Calibrated by Reanalysis"
bss90_sig_by_rn <- c4h_convert(bss90_sig_by_rn, "data.frame", drop = TRUE)
bss90_sig_by_rn$metric <- "BSS90"
bss90_sig_by_rn$type <- "significance"
bss90_sig_by_rn$Source <- "Forecast Calibrated by Reanalysis"
rpss_val_by_rn <- c4h_convert(rpss_val_by_rn, "data.frame", drop = TRUE)
rpss_val_by_rn$metric <- "RPSS"
rpss_val_by_rn$type <- "value"
rpss_val_by_rn$Source <- "Forecast Calibrated by Reanalysis"
rpss_sig_by_rn <- c4h_convert(rpss_sig_by_rn, "data.frame", drop = TRUE)
rpss_sig_by_rn$metric <- "RPSS"
rpss_sig_by_rn$type <- "significance"
rpss_sig_by_rn$Source <- "Forecast Calibrated by Reanalysis"
rmse_val_by_rn  <- c4h_convert( rmse_val_by_rn, "data.frame", drop = TRUE)
rmse_val_by_rn$metric <- "RMSE"
rmse_val_by_rn$type <- "value"
rmse_val_by_rn$Source <- "Forecast Calibrated by Reanalysis"
rmse_cfl_by_rn  <- c4h_convert( rmse_cfl_by_rn, "data.frame", drop = TRUE)
rmse_cfl_by_rn$metric <- "RMSE"
rmse_cfl_by_rn$type <- "conf.lower"
rmse_cfl_by_rn$Source <- "Forecast Calibrated by Reanalysis"
rmse_cfu_by_rn  <- c4h_convert( rmse_cfu_by_rn, "data.frame", drop = TRUE)
rmse_cfu_by_rn$metric <- "RMSE"
rmse_cfu_by_rn$type <- "conf.upper"
rmse_cfu_by_rn$Source <- "Forecast Calibrated by Reanalysis"

# Bind rows for plotting
skill_long <- rbind(bss10_val_cal, bss10_sig_cal,
                    bss90_val_cal, bss90_sig_cal,
                    rpss_val_cal, rpss_sig_cal,
                    rmse_val_cal, rmse_cfl_cal, rmse_cfu_cal,
                    bss10_val_raw, bss10_sig_raw,
                    bss90_val_raw, bss90_sig_raw,
                    rpss_val_raw, rpss_sig_raw,
                    rmse_val_raw, rmse_cfl_raw, rmse_cfu_raw,
                    bss10_val_by_rn, bss10_sig_by_rn,
                    bss90_val_by_rn, bss90_sig_by_rn,
                    rpss_val_by_rn, rpss_sig_by_rn,
                    rmse_val_by_rn,
                    rmse_cfl_by_rn, rmse_cfu_by_rn
                    ) %>%
  as.data.frame() %>%
  select(-c(location, latitude, longitude, sdate, date))

# Extract metrics and types
skill_values <- skill_long %>%
  filter(type == "value") %>%
  select(time, metric, Source, value)

skill_sig <- skill_long %>%
  filter(type == "significance") %>%
  select(time, metric, Source, significant = value)

skill_conf <- skill_long %>%
  filter(type %in% c("conf.lower", "conf.upper")) %>%
  select(time, metric, Source, type, value) %>%
  tidyr::pivot_wider(names_from = type, values_from = value)

skill_wide <- skill_values %>%
  left_join(skill_sig, by = c("time", "metric", "Source")) %>%
  left_join(skill_conf, by = c("time", "metric", "Source")) %>%
  mutate(significant = as.logical(significant))

y_limits_bss <- data.frame(
  metric = c("BSS10", "BSS10", "BSS90", "BSS90", "RPSS", "RPSS"),
  value = c(-0.75, 1, -0.75, 1, -0.75, 1)  # adjust to your desired shared range
)

p_skill <- ggplot(skill_wide, aes(x = time, color = Source, fill = Source)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_ribbon(data = filter(skill_wide, !is.na(conf.lower)),
              aes(ymin = conf.lower, ymax = conf.upper, y = value),
              alpha = 0.15, color = NA) +
  geom_line(aes(y = value)) +
  geom_point(data = filter(skill_wide, !is.na(significant)),
             aes(y = value, shape = significant), size = 2) +
  geom_blank(data = y_limits_bss, aes(x = 1, y = value), inherit.aes = FALSE) +
  scale_shape_manual(values = c("TRUE" = 16, "FALSE" = 1),
                     name = "Significance",
                     labels = c("TRUE" = "Significant",
                                "FALSE" = "Not significant")) +
  scale_color_manual(values = color_values,
                     name = "Data Source") +
  scale_fill_manual(values = color_values,
                     name = "Data Source") +
  facet_wrap(~ metric, scales = "free_y", ncol = 1) +
  theme_minimal() +
  labs(x = "Lead time (months)", y = "Skill Score Value",
       title = "Forecast Initialised: Jan 2025 (Reference Period: 2000 - 2024)") +
  theme(legend.position = "bottom")

ggsave("figures/Brazil/skill_plot_fcst.png", p_skill,
       width = 11, height = 8, dpi = 300)
ggsave("figures/Brazil/skill_plot_fcst.jpg", p_skill,
       width = 11, height = 8, dpi = 300)
ggsave("figures/Brazil/skill_plot_fcst.pdf", p_skill,
       device = grDevices::cairo_pdf,
       width = 11, height = 8, dpi = 300)