# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 02_calibrate_Colombia.R
# Description: Load, aggregate, and calibrate forecast data for Colombia.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-05-04
# Environment: local
# ------------------------------------------------------------------------------

library(sf)
library(devtools)

clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
devtools::load_all(clim4health_path)
data_path <- "data/raw"
var <- "tp"
longname <- "total_precipitation"

### reanalysis temperature ###
### for Colombia ###
eraname <- paste0("era5land_", var)
hindname <- paste0("hindcast_", var)
fcstname <- paste0("forecast_", var)

path_era  <- paste0(data_path, "/Colombia/era5land/")
path_hind <- paste0(data_path, "/Colombia/hindcast/")
path_fcst <- paste0(data_path, "/Colombia/forecast/")

munip_path <- system.file("extdata", "areas", "munip_vallecauca.gpkg",
                          package = "clim4health")
munip <- read_sf(munip_path)

llf <- list()
lls <- list()

for (j in 7:12) {
  hind <- c4h_load(paste0(path_hind, "/", sprintf("%02d", j), "/"),
                   variable = "tprate", ext = "nc")
  hind$data <- hind$data * 3600 * 24 * 30.44 * 1000 # convert m/s to mm/month

  fcst <- c4h_load(paste0(path_fcst, "/", sprintf("%02d", j), "/"),
                   variable = "tprate", ext = "nc")
  fcst$data <- fcst$data * 3600 * 24 * 30.44 * 1000 # convert m/s to mm/month

  rean <- c4h_load(path_era, variable = "tp", ext = "nc", leadtime_month = 1,
                   year = 1981:2016)
  rean$data  <- rean$data * 1000 * 30.44 # convert m/day to mm/month

  hind <- c4h_space(hind, munip, fun = "mean",
                    areas_id = "munip_code")
  fcst <- c4h_space(fcst, munip, fun = "mean",
                    areas_id = "munip_code")
  rean <- c4h_space(rean, munip, fun = "mean",
                    areas_id = "munip_code")

  hind_cal <- c4h_downscale("Intbc", bc_method = "quantile_mapping",
                            exp = hind, obs = rean,
                            method_remap = "con")
  fcst_cal <- c4h_downscale("Intbc", bc_method = "quantile_mapping",
                            exp = hind, obs = rean,
                            exp_cor = fcst,
                            method_remap = "con")
  fcst_cal$exp$attrs$Dates <-
    lubridate::add_with_rollback(fcst_cal$exp$attrs$Dates,
                                 months(j - 10))

  llf[[length(llf) + 1]] <- fcst_cal$exp
  skill_cal <- c4h_verify(hind_cal$exp, hind_cal$obs,
                               metrics = c("CRPSS", "RMSE"))

  skill_cal$CRPSS$crpss$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$CRPSS$crpss$attrs$Dates,
                                 months(j - 10))
  lls[[length(lls) + 1]] <- skill_cal$CRPSS$crpss

}

forecast <- CSTools::CST_BindDim(llf, "sdate")
forecast$attrs <- llf[[1]]$attrs

forecast$attrs$Dates <- do.call(c, lapply(llf, function(x) x$attrs$Dates))
dim(forecast$attrs$Dates) <- c("sdate" = 6, "time" = 1)

p1 <- c4h_plot(forecast, ensemble = TRUE,
               title = "Predicted October 2024 precipitation (mm/month)",
               legend = "Precipitation\n(mm/month)",
               centering = 750,
               palette = "BrBG")
p1 <- p1 + ggplot2::scale_fill_continuous(palette = "BrBG", limits = c(0, 1700))

ggplot2::ggsave(paste0(data_path, "/Colombia/precipitation_forecast.png"),
                plot = p1, width = 8, height = 6, dpi = 300)

skill <- CSTools::CST_BindDim(lls, "time")
skill$attrs <- llf[[1]]$attrs
skill$attrs$Dates <- do.call(c, lapply(llf, function(x) x$attrs$Dates))
dim(skill$attrs$Dates) <- c("sdate" = 1, "time" = 6)

skill <- c4h_index(skill, lower_threshold = 0, closed = TRUE)

p1 <- c4h_plotskill(skill, ensemble = TRUE,
                    title = "Prediction Skill",
                    legend = "CRPSS",
                    palette = "Reds")


ggplot2::ggsave(paste0(data_path, "/Colombia/precipitation_skill.png"),
                plot = p1, width = 8, height = 6, dpi = 300)

rean_tmp <- rean
rean_clim <- s2dv::MeanDims(rean_tmp$data,
                            dim = "sdate", drop = FALSE)

rean_tmp$data <- rean_clim
rean_tmp$attrs$Dates <- c(as.POSIXct("2025-10-01"))
dim(rean_tmp$attrs$Dates) <- c("sdate" = 1, "time" = 1)
rean_tmp$dims <- dim(rean_tmp$data)

p1 <- c4h_plot(rean_tmp,
               title = "October Climatological Precipitation",
               legend = "Precipitation\n(mm/month)",
               centering = 750,
               palette = "BrBG")
p1 <- p1 + ggplot2::scale_fill_continuous(palette = "BrBG", limits = c(0, 1700))

ggplot2::ggsave(paste0(data_path, "/Colombia/precipitation_climatology.png"),
                plot = p1, width = 5, height = 4, dpi = 300)

rean <- c4h_load(path_era, variable = "tp", ext = "nc", leadtime_month = 1,
                 year = 2024)
rean$data  <- rean$data * 1000 * 30.44 # convert m/day to mm/month

rean <- c4h_space(rean, munip, fun = "mean",
                  areas_id = "munip_code")

p2 <- c4h_plot(rean,
               title = "October 2024 Precipitation",
               legend = "Precipitation\n(mm/month)",
               centering = 750,
               palette = "BrBG")

p2 <- p2 + ggplot2::scale_fill_continuous(palette = "BrBG", limits = c(0, 1700))
ggplot2::ggsave(paste0(data_path, "/Colombia/precipitation_observed.png"),
                plot = p2, width = 5, height = 4, dpi = 300)


anom <- rean
anom$data <- rean$data - rean_tmp$data

p2 <- c4h_plot(anom,
               title = "October 2024 Precipitation Anomaly",
               legend = "Precipitation\nAnomaly\n(mm/month)",
               centering = 0)
p2 <- p2 +
  ggplot2::scale_fill_distiller(
    name = "Precipitation\nAnomaly\n(mm/month)",
    palette = "RdBu", direction = 1,
    limits = c(-max(abs(anom$data)), max(abs(anom$data)))
  )
ggplot2::ggsave(paste0(data_path, "/Colombia/precipitation_anomaly.png"),
                plot = p2, width = 5, height = 4, dpi = 300)