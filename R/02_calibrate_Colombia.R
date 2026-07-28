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

# --- Set paths ---
clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
data_path <- "data/raw"
fig_path <- "figures/Colombia/"

# --- Load libraries ---
library(sf)
library(devtools)
library(ggplot2)
library(cowplot)
devtools::load_all(clim4health_path)

# --- Set parameters ---
target_month <- 12
target_year  <- 2025
var <- "tp"
longname <- "total_precipitation"
nmonth <- 6

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
sig <- list()

bs9 <- list()
sig9 <- list()
bs1 <- list()
sig1 <- list()

# --- Load and aggregate reanalysis data ---
rean <- c4h_load(rean_path,
                 variable = "tp",
                 year = 1981:2016,
                 month = target_month,
                 leadtime_month = 1,
                 bbox = c(5.5, -78, 3.0, -75),
                 ext = "nc")
rean$attrs$Dates <- as.Date(rean$attrs$Dates)

rean$data  <- rean$data * 1000 * 30.44 # convert m/day to mm/month

rean <- c4h_space(rean, munip, fun = "mean",
                  areas_id = "munip_code")

# --- For each initialization month, load and aggregate hindcast
# --- and forecast data, then calibrate ---
for (ij in (target_month - nmonth + 1):target_month) {
  # calculate initialization month
  j <- ij %% 12
  if (j == 0) {
    j <- 12
  }

  # calculate lead time month
  lj <- (target_month - j + 1) %% 12
  if (lj == 0) {
    lj <- 12
  }

  # calculate target year for forecast
  if (ij <= 0) {
    year <- target_year - 1
  } else {
    year <- target_year
  }

  print("Loading hindcast")
  hind <- c4h_load(paste0(path_hind, "/", sprintf("%02d", j), "/"),
                   variable = "tprate", ext = "nc")
  hind$data <- hind$data * 3600 * 24 * 30.44 * 1000 # convert m/s to mm/month

  fcst <- c4h_load(paste0(path_fcst, "/", sprintf("%02d", j), "/"),
                   variable = "tprate", ext = "nc")
  fcst$data <- fcst$data * 3600 * 24 * 30.44 * 1000 # convert m/s to mm/month

  hind <- c4h_space(hind, munip, fun = "mean",
                    areas_id = "munip_code")
  fcst <- c4h_space(fcst, munip, fun = "mean",
                    areas_id = "munip_code")

  hind_cal <- c4h_downscale("Intbc", method_bc = "quantile_mapping",
                            exp = hind, obs = rean,
                            method_remap = "con")
  fcst_cal <- c4h_downscale("Intbc", method_bc = "quantile_mapping",
                            exp = hind, obs = rean,
                            exp_cor = fcst,
                            method_remap = "con")
  fcst_cal$exp$attrs$Dates <-
    lubridate::add_with_rollback(fcst_cal$exp$attrs$Dates,
                                 months(ij - target_month))

  llf[[length(llf) + 1]] <- fcst_cal$exp
  skill_cal <- c4h_verify(hind_cal$exp, hind_cal$obs,
                          metrics = c("RPSS", "BSS"))

  skill_cal$RPSS$rpss$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$RPSS$rpss$attrs$Dates,
                                 months(ij - target_month))
  lls[[length(lls) + 1]] <- skill_cal$RPSS$rpss

  skill_cal$RPSS$sign$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$RPSS$sign$attrs$Dates,
                                 months(ij - target_month))
  sig[[length(sig) + 1]] <- skill_cal$RPSS$sign

  skill_cal$BSS90$bss$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$BSS90$bss$attrs$Dates,
                                 months(ij - target_month))
  bs9[[length(bs9) + 1]] <- skill_cal$BSS90$bss

  skill_cal$BSS90$sign$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$BSS90$sign$attrs$Dates,
                                 months(ij - target_month))
  sig9[[length(sig9) + 1]] <- skill_cal$BSS90$sign

  skill_cal$BSS10$bss$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$BSS10$bss$attrs$Dates,
                                 months(ij - target_month))
  bs1[[length(bs1) + 1]] <- skill_cal$BSS10$bss

  skill_cal$BSS10$sign$attrs$Dates <-
    lubridate::add_with_rollback(skill_cal$BSS10$sign$attrs$Dates,
                                 months(ij - target_month))
  sig1[[length(sig1) + 1]] <- skill_cal$BSS10$sign
}

forecast <- CSTools::CST_BindDim(llf, "sdate")
forecast$attrs <- llf[[1]]$attrs

forecast$attrs$Dates <- do.call(c, lapply(llf, function(x) x$attrs$Dates))
dim(forecast$attrs$Dates) <- c("sdate" = nmonth, "time" = 1)

lng_nm <- "Precipitation"
leg_label <- "Precipitation\n(mm/month)"
lims <- c(0, 1500)
pal <- "BrBG"
p1 <- c4h_plot(forecast, ensemble = TRUE,
               title = paste0("Target Month: ", month.name[target_month], " ",
                              target_year),
               legend = leg_label,
               palette = pal)
p1 <- p1 + ggplot2::scale_fill_continuous(palette = pal, limits = lims)

ggplot2::ggsave(paste0(fig_path, var, "_forecast_",
                       target_month, "_", target_year, ".png"),
                plot = p1, width = 8, height = 6, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_forecast_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p1, width = 8, height = 6, dpi = 300)

skill <- CSTools::CST_BindDim(lls, "time")
skill$attrs <- llf[[1]]$attrs
skill$attrs$Dates <- do.call(c, lapply(llf, function(x) x$attrs$Dates))
dim(skill$attrs$Dates) <- c("sdate" = 1, "time" = nmonth)

signif <- CSTools::CST_BindDim(sig, "time")
signif$attrs <- llf[[1]]$attrs
signif$attrs$Dates <- do.call(c, lapply(llf, function(x) x$attrs$Dates))
dim(signif$attrs$Dates) <- c("sdate" = 1, "time" = nmonth)

p2 <- c4h_plotskill(skill, sign = signif,
                    title = paste0("Prediction Skill, Target Month: ",
                                   month.name[target_month], " ",
                                   target_year),
                    legend = "RPSS")

p2 <- p2 +
  ggplot2::facet_wrap(
    stats::as.formula("~time"),
    labeller = ggplot2::as_labeller(function(x) paste0("sdate: ", x))
  )
ggplot2::ggsave(paste0(fig_path, var, "_rpss_",
                       target_month, "_", target_year, ".png"),
                plot = p2, width = 8, height = 6, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_rpss_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p2, width = 8, height = 6, dpi = 300)


skill90 <- CSTools::CST_BindDim(bs9, "time")
skill90$attrs <- bs9[[1]]$attrs
skill90$attrs$Dates <- skill$attrs$Dates

sign90 <- CSTools::CST_BindDim(sig9, "time")
sign90$attrs <- sig9[[1]]$attrs
sign90$attrs$Dates <- signif$attrs$Dates

p3 <- c4h_plotskill(skill90, sign = sign90,
                    title = paste0("Prediction Skill, Target Month: ",
                                   month.name[target_month], " ",
                                   target_year),
                    legend = "BSS90")

ggplot2::ggsave(paste0(fig_path, var, "_bss90_",
                       target_month, "_", target_year, ".png"),
                plot = p3, width = 8, height = 6, dpi = 300)

ggplot2::ggsave(paste0(fig_path, var, "_bss90_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p3, width = 8, height = 6, dpi = 300)


skill10 <- CSTools::CST_BindDim(bs1, "time")
skill10$attrs <- bs1[[1]]$attrs
skill10$attrs$Dates <- skill$attrs$Dates

sign10 <- CSTools::CST_BindDim(sig1, "time")
sign10$attrs <- sig1[[1]]$attrs
sign10$attrs$Dates <- signif$attrs$Dates

p4 <- c4h_plotskill(skill10, sign = sign10,
                    title = paste0("Prediction Skill, Target Month: ",
                                   month.name[target_month], " ",
                                   target_year),
                    legend = "BSS10")

ggplot2::ggsave(paste0(fig_path, var, "_bss10_",
                       target_month, "_", target_year, ".png"),
                plot = p4, width = 8, height = 6, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_bss10_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p4, width = 8, height = 6, dpi = 300)

rean_tmp <- rean
rean_clim <- c4h_collapse(rean_tmp, dim = "sdate", fun = "mean")

p5 <- c4h_plot(rean_clim,
               title = paste0(month.name[target_month],
                              " Climatology"),
               legend = leg_label,
               palette = pal)
p5 <- p5 + ggplot2::scale_fill_continuous(palette = pal, limits = lims)

ggplot2::ggsave(paste0(fig_path, var, "_climatology_",
                       target_month, ".png"),
                plot = p5, width = 5, height = 4, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_climatology_",
                       target_month, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p5, width = 5, height = 4, dpi = 300)

rean_obs <- c4h_load(rean_path,
                     variable = var,
                     ext = "nc",
                     month = target_month,
                     bbox = c(5.5, -78, 3.0, -75),
                     leadtime_month = 1,
                     year = target_year)
if (var == "prlr") {
  rean_obs$data  <- rean_obs$data * 3600 * 24 * 30.44 * 1000 # convert
} else if (var == "tas") {
  rean_obs <- c4h_convert_units(rean_obs, to = "celsius") # convert K to C
}
rean_obs$attrs$Dates <- as.Date(rean_obs$attrs$Dates)

rean_obs <- c4h_space(rean_obs, munip, fun = "mean",
                      areas_id = "munip_code")

p6 <- c4h_plot(rean_obs,
               title = paste0(month.name[target_month], " ",
                              target_year, " ", lng_nm),
               legend = leg_label,
               palette = pal)

p6 <- p6 + ggplot2::scale_fill_continuous(palette = pal, limits = lims)
ggplot2::ggsave(paste0(fig_path, var, "_observed_",
                       target_month, "_", target_year, ".png"),
                plot = p6, width = 5, height = 4, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_observed_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p6, width = 5, height = 4, dpi = 300)


anom <- rean_obs
anom$data <- rean_obs$data - rean_clim$data

if (var == "prlr") {
  leg_label <- "Precipitation\nAnomaly\n(mm/month)"
  dir <- 1
} else if (var == "tas") {
  leg_label <- "Temperature\nAnomaly (°C)"
  dir <- -1
}

p7 <- c4h_plot(anom,
               title = paste0(month.name[target_month], " ",
                              target_year, " Anomaly"),
               legend = leg_label)
p7 <- p7 +
  ggplot2::scale_fill_distiller(
    name = leg_label,
    palette = "RdBu", direction = dir,
    limits = c(-max(abs(anom$data)), max(abs(anom$data)))
  )
ggplot2::ggsave(paste0(fig_path, var, "_anomaly_",
                       target_month, "_", target_year, ".png"),
                plot = p7, width = 5, height = 4, dpi = 300)
ggplot2::ggsave(paste0(fig_path, var, "_anomaly_",
                       target_month, "_", target_year, ".pdf"),
                device = grDevices::cairo_pdf,
                plot = p7, width = 5, height = 4, dpi = 300)