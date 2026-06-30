# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 07_download_Peru.R
# Description: Download raw data required for the analysis.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-04-13
# Environment: local
# ------------------------------------------------------------------------------

# Section 1 ----
vars <- c("t2m")
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

### reanalysis temperature ###
outname <- "era5land_t2m"

path_out <- paste0(data_path, "/Peru/era5land/")


for (i in 2011:2025) {
  for (j in 1:12) {
    if (!file.exists(paste0(path_out, outname, "_",
                            i, sprintf("%02d", j), ".nc"))) {
      c4h_get(pat = pat_api,
              dataset = "reanalysis-era5-land",
              product_type = "reanalysis",
              variable = "2m_temperature",
              year = i,
              month = j,
              time = 1:23,
              bbox = c(-1.0, -76, -6, -70),
              outname = outname,
              outpath = path_out)
    }
  }
}
