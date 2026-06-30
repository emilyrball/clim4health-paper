# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 08_station_to_s2dv_Peru.R
# Description: Load station data for Peru and convert to s2dv format.
#
# Author(s): Emily Ball
# Date created: 2026-04-13
# Last updated: 2026-04-13
# Environment: local
# ------------------------------------------------------------------------------

## load libraries and set paths ##
library(devtools)
library(readxl)

clim4health_path <- "/home/eball/gitlab_repos/clim4health/"
devtools::load_all(clim4health_path)

path_out <- "data/raw/Peru/obs/"
####################################################################

# extract data, in this case from an excel file #
data <- readxl::read_excel(paste0(path_out,
                                  "meteorological_data_hmz_stations.xlsx"))

# look at the column names to identify variables #
print(names(data))

# extract dates and order them - these will be the dates attribute #
dates <- as.POSIXct(data$record_date, format = "%Y/%m/%d")
unique_dates <- unique(dates)
unique_dates <- unique_dates[order(unique_dates)]
####################################################################

# extract locations and variable names #
locations <- unique(data$ccpp_name)
# remove the date and location columns
vars <- names(data)[-c(1, 2)]
# in this case the file does not contaion the lat/lon of each station,
# so we hardcode them here. In other cases, these could also be extracted
# from the file and matched to the location names.
lats <- c( -3.83,  -4.10,  -3.89,  -4.22,  -4.04,  -3.98)
lons <- c(-73.33, -73.46, -73.36, -73.48, -73.44, -73.36)
####################################################################

# in this case make a time series array so sdate = 1
# there are dataset, var, sdate, time, ensemble, location dimensions
# dataset, sdate, ensemble are all 1 in this example (and likely for many
# station datasets) but we include them for consistency with the clim4health
# s2dv_cube format.
data_new <- array(NA, dim = c(1, length(vars), 1,
                              length(unique_dates), 1, length(locations)))
attr_dates <- array(unique_dates, dim = c(1, length(unique_dates)))
attr_dates <- as.POSIXct(attr_dates, origin = "1970-01-01")

# assign data to the new array #
for (i in seq_along(locations)) {
  # select data for each station #
  station_data <- data[data$ccpp_name == locations[i], ]
  for (j in seq_along(unique_dates)) {
    # get indices in the file for each date #
    idx <- which(station_data$record_date == unique_dates[j])
    # get indices in the date array for each date #
    dates_idx <- which(unique_dates[j] == station_data$record_date)
    if (length(idx) > 0) {
      for (var in vars) {
        data_new[1, which(vars == var), 1, dates_idx, 1, i] <-
          station_data[idx, ][[var]]
      }
    }
  }
}

### set the array names ###
names(dim(data_new)) <- c("dataset", "var", "sdate", "time",
                          "ensemble", "location")
### ensure the dates attribute has correct names ###
names(dim(attr_dates)) <- c("sdate", "time")

### define the coordinates ###
coords <- list(dataset = 1,
               var = vars,
               sdate = 1,
               time = seq_along(unique_dates),
               ensemble = 1,
               location = seq_along(locations))

### create the s2dv_cube ###
# in this case, we use the function CSTools::s2dv_cube to create the s2dv_cube #
### but it is possible to create it by manually assigning elements of a list ###
data <- CSTools::s2dv_cube(
  data = data_new,
  coords = coords,
  varName = vars,
  Dates = attr_dates,
  metadata = list(source_files = paste0(path_out,
                                        "meteorological_data",
                                        "_hmz_stations.xlsx"))
)
# add the lat/lon as attributes - these could also be added as coordinates
# if desired. Also add the station names as an attribute for reference.
data$attrs$location <- list(latitude = lats, longitude = lons)
data$attrs$station_names <- locations
saveRDS(data, paste0(path_out, "peru.rds"))