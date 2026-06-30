# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 01_download_Colombia.R
# Description: Download raw data required for the analysis.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-04-13
# Environment: local
# ------------------------------------------------------------------------------

# Section 1 ----
library(devtools)
clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
devtools::load_all(clim4health_path)
data_path <- "data/raw"
var <- "tp"

if (var == "t2m") {
  longname <- "2m_temperature"
} else if (var == "tp") {
  longname <- "total_precipitation"
}

### reanalysis temperature ###
### for Colombia ###
outname <- paste0("era5land_", var)
path_era  <- paste0(data_path, "/Colombia/era5land/")
path_hind <- paste0(data_path, "/Colombia/hindcast/")
path_fore <- paste0(data_path, "/Colombia/forecast/")

for (i in 1981:2025) {
  for (j in 12) {
    if (!file.exists(paste0(path_era, outname, "_",
                            i, sprintf("%02d", j), ".nc"))) {
      print(paste0(path_era, outname, "_",
                   i, sprintf("%02d", j), ".nc"))
      c4h_get(pat = pat_api,
              dataset = "reanalysis-era5-land-monthly-means",
              product_type = "monthly_averaged_reanalysis",
              variable = longname,
              year = i,
              month = j,
              bbox = c(5.5, -78, 3.0, -75),
              outname = outname,
              outpath = path_era)
    }
  }
}

### hindcast temperature ###
outname <- paste0("hindcast_", var)

for (j in 7:12) {
  for (i in 1981:2016) {
    if (!file.exists(paste0(path_hind, "/", sprintf("%02d", j),
                            "/", outname, "_",
                            i, sprintf("%02d", j), ".nc"))) {
      print(paste0(path_hind, "/", sprintf("%02d", j),
                   "/", outname, "_",
                   i, sprintf("%02d", j), ".nc"))
      c4h_get(pat = pat_api,
              dataset = "seasonal-monthly-single-levels",
              originating_centre = c("ecmwf"),
              system = c("51"),
              variable = c(longname),
              product_type = c("monthly_mean"),
              year = i,
              month = j,
              leadtime_month = 12 - j + 1,
              bbox = c(5.5, -78, 3.0, -75),
              outname = outname,
              outpath = paste0(path_hind, "/", sprintf("%02d", j), "/"))
    }
  }
}

# get forecasts
### forecast precipitation ###

outname <- paste0("forecast_", var)
for (j in 7:12) {
  for (i in 2024) {
    if (!file.exists(paste0(path_fore, "/", sprintf("%02d", j),
                            "/", outname, "_",
                            i, sprintf("%02d", j), ".nc"))) {
      print(paste0(path_fore, "/", sprintf("%02d", j),
                   "/", outname, "_",
                   i, sprintf("%02d", j), ".nc"))
      c4h_get(pat = pat_api,
              dataset = "seasonal-monthly-single-levels",
              originating_centre = c("ecmwf"),
              system = c("51"),
              variable = c(longname),
              product_type = c("monthly_mean"),
              year = i,
              month = j,
              leadtime_month = 12 - j + 1,
              bbox = c(5.5, -78, 3.0, -75),
              outname = outname,
              outpath = paste0(path_fore, "/", sprintf("%02d", j), "/"))
    }
  }
}