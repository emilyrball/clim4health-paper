# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 06_downscale_DominicanRepublic_esarchive.R
# Description: Downscale forecast data for the Dominican Republic and evaluate
#              skill. Using data stored on esarchive.
#
# Author(s): Emily Ball
# Date created: 2026-06-01
# Last updated: 2026-06-03
# Environment: hub
# ------------------------------------------------------------------------------

# --- Set paths ---
clim4health_path <- "/esarchive/scratch/eball/gitlab_repos/clim4health/"
exp_path <- "/esarchive/exp/ecmwf/system51c3s/monthly_mean/"
rec_path <- "/esarchive/recon/ecmwf/era5land/monthly_mean/"
fig_path <- "figures/DominicanRepublic/"
munip_path <- "data/raw/DominicanRepublic/do_shp/do.shp"

# Load file in local interactively
ncdf4::nc_open(paste0(clim4health_path,
                      "inst/extdata/forecast/t2m_20250101.nc"))

# --- Load libraries ---
library(sf)
library(devtools)
devtools::load_all(clim4health_path)

# --- Set parameters ---
init_month <- 5
var <- "tas"
fcst_year <- 2025

if (var == "prlr") {
  hind_path <-
    paste0(exp_path, "prlr_s0-24h/")
  rean_path <-
    paste0(rec_path, "prlr_f1h/")
} else if (var == "tas") {
  hind_path <-
    paste0(exp_path, "tas_f6h/")
  rean_path <-
    paste0(rec_path, "tas_f1h/")
}

# --- Load municipality boundaries ---
munip <- read_sf(munip_path)
aoi <- munip %>% st_transform(4326)

# --- Load reanalysis data ---
rean <- c4h_load(rean_path,
                 variable = var,
                 year = 1981:2016,
                 month = init_month,
                 leadtime_month = 1:6,
                 bbox = c(21, -72.5, 17.5, -68.5),
                 ext = "nc")
rean <- c4h_convert_units(rean, var = var, from = "K", to = "celsius")
rean$attrs$Dates <- as.Date(rean$attrs$Dates)
# --- Load hindcast data ---
hind <- c4h_load(hind_path,
                 variable = var,
                 year = 1981:2016,
                 month = init_month,
                 leadtime_month = 1:6,
                 bbox = c(21, -72.5, 17.5, -68.5),
                 ext = "nc")
hind <- c4h_convert_units(hind, var = var, from = "K", to = "celsius")
hind$attrs$Dates <- as.Date(hind$attrs$Dates)
# --- Load forecast data ---
fcst <- c4h_load(hind_path,
                 variable = var,
                 year = fcst_year,
                 month = init_month,
                 leadtime_month = 1:6,
                 bbox = c(21, -72.5, 17.5, -68.5),
                 ext = "nc")
fcst <- c4h_convert_units(fcst, var = var, from = "K", to = "celsius")
fcst$attrs$Dates <- as.Date(fcst$attrs$Dates)
# --- Load observed data ---
obs <- c4h_load(rean_path,
                variable = var,
                year = fcst_year,
                month = init_month,
                leadtime_month = 1:6,
                bbox = c(21, -72.5, 17.5, -68.5),
                ext = "nc")
obs <- c4h_convert_units(obs, var = var, from = "K", to = "celsius")
obs$attrs$Dates <- as.Date(obs$attrs$Dates)
# --- Downscale hindcast and forecast data ---
hind_cal <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hind, obs = rean,
                          method_remap = "bilinear")
fcst_cal <- c4h_downscale("Intbc", method_bc = "evmos",
                          exp = hind, obs = rean,
                          exp_cor = fcst,
                          method_remap = "bilinear")

# --- Evaluate skill ---
skill_cal <- c4h_verify(hind_cal$exp, hind_cal$obs,
                        metrics = c("CRPSS", "RMSE"))

# --- Plot downscaled forecast data ---
p1 <- c4h_plot(fcst_cal$exp, ensemble = TRUE,
               title = "Downscaled Predicted May-October 2025 Temperature",
               legend = "Temperature\n(°C)",
               boundaries = aoi,
               mask_boundaries = TRUE)
p1 <- p1 + ggplot2::scale_fill_continuous(palette = "YlOrRd",
                                          limits = c(14, 32),
                                          na.value = "transparent")
ggplot2::ggsave(paste0(fig_path, "/downscaled_",
                       "temperature_forecast.png"),
                plot = p1, width = 8, height = 4, dpi = 300)

# --- Crop raw forecast data to plot smaller area ---
fcst_tmp <- fcst
fcst_tmp$attrs$Variable$varName <- "var_tmp"
fcst_tmp$attrs$Variable$metadata <- list(var_tmp = list(units = "C"))
fcst_tmp <- CSTools::CST_Subset(fcst_tmp, along = "latitude",
                                indices = 1:(fcst_tmp$dims["latitude"] - 1))

p2 <- c4h_plot(fcst_tmp, ensemble = TRUE,
               title = "Predicted May-October 2025 Temperature",
               legend = "Temperature\n(°C)",
               boundaries = aoi)

p2 <- p2 + ggplot2::scale_fill_continuous(palette = "YlOrRd",
                                          limits = c(14, 32),
                                          na.value = "transparent")
ggplot2::ggsave(paste0(fig_path,
                       "/raw_",
                       "temperature_forecast.png"),
                plot = p2, width = 8, height = 4, dpi = 300)

# --- Plot observed data ---
p3 <- c4h_plot(obs,
               title = "Observed May-October 2025 Temperature",
               legend = "Temperature\n(°C)",
               boundaries = aoi,
               mask_boundaries = TRUE)
p3 <- p3 + ggplot2::scale_fill_continuous(palette = "YlOrRd",
                                          limits = c(14, 32),
                                          na.value = "transparent")
ggplot2::ggsave(paste0(fig_path,
                       "/observed_",
                       "temperature.png"),
                plot = p3, width = 8, height = 4, dpi = 300)

# --- Plot skill ---
p4 <- c4h_plotskill(skill_cal$CRPSS$crpss,
                    sign = skill_cal$CRPSS$sign,
                    title = "Prediction Skill",
                    legend = "CRPSS",
                    boundaries = aoi,
                    mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/temperature_skill_crpss.png"),
                plot = p4, width = 8, height = 4, dpi = 300)

p5 <- c4h_plot(skill_cal$RMSE$rmse,
               title = "Prediction Skill",
               legend = "RMSE",
               palette = "Reds",
               boundaries = aoi,
               mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/temperature_skill_rmse.png"),
                plot = p5, width = 8, height = 4, dpi = 300)

# --- Calculate hypothetical threshold-based suitability ---
hind_aedes <- c4h_index(hind_cal$exp, return_mask = TRUE,
                        lower_threshold = 25)
fcst_aedes <- c4h_index(fcst_cal$exp, return_mask = TRUE,
                        lower_threshold = 25)
obs_aedes  <- c4h_index(obs, return_mask = TRUE,
                        lower_threshold = 25)
rean_aedes <- c4h_index(hind_cal$obs, return_mask = TRUE,
                        lower_threshold = 25)

# --- Evaluate skill of suitability predictions ---
skill_aedes <- c4h_verify(hind_aedes, rean_aedes,
                          metrics = c("BSS", "CRPSS"),
                          brier_thresholds = c(0.1, 0.5, 0.9))

# --- Plot suitability forecast ---
p7 <- c4h_plot(fcst_aedes, ensemble = TRUE,
               title = paste0("Downscaled Predicted May-October",
                              "2025 Example Suitability"),
               legend = "Probability\nsuitability",
               boundaries = aoi,
               palette = "Reds",
               mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/downscaled_",
                       "aedes_aegypti_forecast.png"),
                plot = p7, width = 8, height = 4, dpi = 300)

# --- Plot observed suitability ---
p8 <- c4h_plot(obs_aedes,
               title = "Observed May-October 2025 Example Suitability",
               legend = "Observed\nsuitability",
               boundaries = aoi,
               palette = "Reds",
               mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/observed_",
                       "aedes_aegypti_suitability.png"),
                plot = p8, width = 8, height = 4, dpi = 300)

# --- Plot skill of suitability predictions ---
p9 <- c4h_plotskill(skill_aedes$BSS50$bss,
                    sign = skill_aedes$BSS50$sign,
                    title = "Prediction Skill",
                    legend = "BSS50",
                    boundaries = aoi,
                    mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/aedes_aegypti_suitability_skill_bss50.png"),
                plot = p9, width = 8, height = 4, dpi = 300)


p9 <- c4h_plotskill(skill_aedes$BSS90$bss,
                    sign = skill_aedes$BSS90$sign,
                    title = "Prediction Skill",
                    legend = "BSS90",
                    boundaries = aoi,
                    mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/aedes_aegypti_suitability_skill_bss90.png"),
                plot = p9, width = 8, height = 4, dpi = 300)

p9 <- c4h_plotskill(skill_aedes$BSS10$bss,
                    sign = skill_aedes$BSS10$sign,
                    title = "Prediction Skill",
                    legend = "BSS10",
                    boundaries = aoi,
                    mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/aedes_aegypti_suitability_skill_bss10.png"),
                plot = p9, width = 8, height = 4, dpi = 300)


p9 <- c4h_plotskill(skill_aedes$CRPSS$crpss,
                    sign = skill_aedes$CRPSS$sign,
                    title = "Prediction Skill",
                    legend = "CRPSS",
                    boundaries = aoi,
                    mask_boundaries = TRUE)
ggplot2::ggsave(paste0(fig_path,
                       "/aedes_aegypti_suitability_skill_crpss.png"),
                plot = p9, width = 8, height = 4, dpi = 300)