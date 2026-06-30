# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 04_download_DominicanRepublic.R
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
vars <- c("t2m")

####
longnames <- c()
for (var in vars) {
  if (var == "t2m") {
    longname <- "2m_temperature"
  } else if (var == "tp") {
    longname <- "total_precipitation"
  } else if (var == "d2m") {
    longname <- "2m_dewpoint_temperature"
  }
  longnames <- c(longnames, longname)
}

### monthly variables ###
### for DR ###
path_daily  <- paste0(data_path, "/DominicanRepublic/era5land/daily/")
path_monthly  <- paste0(data_path, "/DominicanRepublic/era5land/monthly/")
path_hind <- paste0(data_path, "/DominicanRepublic/hindcast/")
path_fore <- paste0(data_path, "/DominicanRepublic/forecast/")

for (i in c(1994:2016, 2025)) {
  for (j in 5:10) {
    if (!file.exists(paste0(path_monthly, "era5land_",
                            i, sprintf("%02d", j), ".nc"))) {
      print(paste0(path_monthly, "era5land_",
                   i, sprintf("%02d", j), ".nc"))
      c4h_get(pat = pat_api,
              dataset = "reanalysis-era5-land-monthly-means",
              product_type = "monthly_averaged_reanalysis",
              variable = longnames,
              year = i,
              month = j,
              bbox = c(20, -72.5, 17, -68),
              outname = "era5land",
              outpath = path_monthly)
    }
  }
  j <- 5
  if (i == 2025) {
    path_seas <- path_fore
    outname <- paste0("forecast")
  } else {
    path_seas <- path_hind
    outname <- paste0("hindcast")
  }
  if (!file.exists(paste0(path_seas, "/",  outname, "_",
                          i, sprintf("%02d", j), ".nc"))) {
    print(paste0(path_seas, "/",  outname, "_",
                 i, sprintf("%02d", j), ".nc"))
    c4h_get(pat = pat_api,
            dataset = "seasonal-monthly-single-levels",
            originating_centre = c("ecmwf"),
            system = c("51"),
            variable = longnames,
            product_type = c("monthly_mean"),
            year = i,
            month = j,
            leadtime_month = 1:6,
            bbox = c(20, -73, 17, -68),
            outname = outname,
            outpath = path_seas)
  }
}