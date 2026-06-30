# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 05_downscale_DominicanRepublic.R
# Description: Downscale forecast data for the Dominican Republic and evaluate
#              skill.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-06-25
# Environment: local
# ------------------------------------------------------------------------------

# --- Set paths ---
clim4health_path <- "/esarchive/scratch/eball/gitlab_repos/clim4health/"
library(devtools)
devtools::load_all(clim4health_path)
data_path <- "data/raw"

path_era  <- paste0(data_path, "/DominicanRepublic/era5land/monthly/")
path_hind <- paste0(data_path, "/DominicanRepublic/hindcast/")
path_fcst <- paste0(data_path, "/DominicanRepublic/forecast/")

vars <- c("t2m")

hind <- c4h_load(path_hind, variable = vars, ext = "nc", month = 5,
                 leadtime_month = 1:6, year = 1994:2016)
rean <- c4h_load(path_era, variable = vars, ext = "nc", month = 5,
                 leadtime_month = 1:6, year = 1994:2016)

fcst <- c4h_load(path_fcst,
                 variable = vars, ext = "nc")
obs  <- c4h_load(path_era, variable = vars, ext = "nc", month = 5,
                 leadtime_month = 1:6, year = 2025)

hind <- c4h_convert_units(hind, variable = vars, from = c("K"),
                          to = c("celsius"))
fcst <- c4h_convert_units(fcst, variable = vars, from = c("K"),
                          to = c("celsius"))
rean <- c4h_convert_units(rean, variable = vars, from = c("K"),
                          to = c("celsius"))


obs  <- c4h_convert_units( obs, variable = vars, from = c("K"),
                          to = c("celsius"))

# --- Downscale hindcast and forecast data ---
hind_cal <- c4h_downscale("Intbc", bc_method = "evmos",
                          exp = hind, obs = rean,
                          method_remap = "bilinear")
fcst_cal <- c4h_downscale("Intbc", bc_method = "evmos",
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
p2 <- c4h_plot(fcst, ensemble = TRUE,
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
p6 <- c4h_plotskill(skill_cal$BSS90$bss,
                    title = "Prediction Skill",
                    legend = "BSS90",
                    centering = 0,
                    boundaries = aoi)
ggplot2::ggsave(paste0(fig_path,
                       "/temperature_skill_bss90.png"),
                plot = p6, width = 8, height = 4, dpi = 300)

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
               title = "Downscaled Predicted May-October 2025 Example Suitability",
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