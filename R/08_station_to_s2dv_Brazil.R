# -----------------------------------------------------------------------------
# Climate Services Team (CST) / Global Health Resilience (GHR)
# Barcelona Supercomputing Center (BSC-CNS)
#
# Script Name: 08_station_to_s2dv_Peru.R
# Description: Load station data for Peru and convert to s2dv format.
#
# Author(s): Emily Ball
# Date created: 2026-07-13
# Last updated: 2026-07-13
# Environment: local
# ------------------------------------------------------------------------------

## load libraries and set paths ##
library(devtools)

clim4health_path <- "/esarchive/scratch/eball/gitlab_repos/clim4health/"
devtools::load_all(clim4health_path)

path_in  <- "data/raw/Brazil/obs/"
path_out <- "data/processed/Brazil/obs/"
####################################################################

# extract data, in this case from an excel file #
station_data <- data.table::fread(paste0(path_in,
                                 "dados_82791_D_2000-01-01_2025-12-31.csv"))

# restrict to 2001 onward
station_data <- station_data[as.Date(`Data Medicao`) >= as.Date("2001-01-01")]

# look at the column names to identify variables #
print(names(station_data))

# extract dates and order them - these will be the dates attribute #
dates <- as.POSIXct(station_data$`Data Medicao`, format = "%Y-%m-%d")
unique_dates <- unique(dates)
unique_dates <- unique_dates[order(unique_dates)]
####################################################################

# for illustration, we will loop over a single station, which could be expanded
# to multiple stations as needed.
locations <- c("Patos")
# remove the date and location columns
vars <- names(station_data)[c(2, 3, 4)]
# in this case the file does not contaion the lat/lon of each station,
# so we hardcode them here. In other cases, these could also be extracted
# from the file and matched to the location names.
lats <- c( -7.05)
lons <- c(-37.27)

# edit the class of the variables to numeric, since they are read in
# as character from the csv file

station_data[, (vars) := lapply(.SD, function(x) {
  x <- gsub(",", ".", x)
  x[x == "null"] <- NA
  as.numeric(x)
}), .SDcols = vars]
####################################################################

# in this case make a time series array so sdate = 1
# there are dataset, var, sdate, time, ensemble, location dimensions
# dataset, sdate, ensemble are all 1 in this example (and likely for many
# station datasets) but we include them for consistency with the clim4health
# s2dv_cube format.
data_new <- array(NA, dim = c(1, length(vars), 1,
                              length(unique_dates), 1, length(locations)))
attr_dates <- array(unique_dates, dim = c(1, length(unique_dates)))
attr_dates <- as.POSIXct(attr_dates, origin = "1970-01-01", tz = "UTC")

# assign data to the new array #
for (i in seq_along(locations)) {
  # select data for each station #
  # in this case we do not need to filter
  # since we only have data for one station
  
  for (j in seq_along(unique_dates)) {
    # get indices in the file for each date #
    idx <- which(station_data$`Data Medicao` == unique_dates[j])
    # get indices in the date array for each date #
    dates_idx <- which(unique_dates[j] == station_data$`Data Medicao`)
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
                                        "dados_82791_D_2000-01-01_2025-12-31.csv"))
)
# add the lat/lon as attributes - these could also be added as coordinates
# if desired. Also add the station names as an attribute for reference.
data$attrs$location <- list(latitude = lats, longitude = lons)
data$attrs$station_names <- locations
saveRDS(data, paste0(path_out, "brazil.rds"))




# ---------------------------------------------------------------------------- #
# obtain monthly average data

stat_monthly <- station_data %>%
  mutate(year = lubridate::year(`Data Medicao`),
         month = lubridate::month(`Data Medicao`)) %>%
  rename(
    temp_max = `TEMPERATURA MAXIMA, DIARIA(°C)`,
    temp_min = `TEMPERATURA MINIMA, DIARIA(°C)`,
    temp_mean = `TEMPERATURA MEDIA COMPENSADA, DIARIA(°C)`
  ) %>%
  dplyr::group_by(year, month) %>%
  dplyr::summarise(
    n_days = lubridate::days_in_month(lubridate::make_date(dplyr::first(year), dplyr::first(month), 1)),
    n_obs_max = sum(!is.na(temp_max)),
    n_obs_min = sum(!is.na(temp_min)),
    n_obs_med = sum(!is.na(temp_mean)),
    temp_max = if (n_obs_max / n_days >= 0.7)
      mean(temp_max, na.rm = TRUE) else NA_real_,
    temp_min = if (n_obs_min / n_days >= 0.7)
      mean(temp_min, na.rm = TRUE) else NA_real_,
    temp_mean = if (n_obs_med / n_days >= 0.7)
      mean(temp_mean, na.rm = TRUE) else NA_real_,
    .groups = "drop"
  )

unique_years <- 2000:2025
unique_months <- 1:12
# in this case make a yearly array so sdate = n_years, time = 12
# there are dataset, var, sdate, time, ensemble, location dimensions

vars <- c("temp_max", "temp_min", "temp_mean")
data_new <- array(NA, dim = c(1, length(vars), length(unique_years),
                              length(unique_months), 1, length(locations)))
dates <- as.POSIXct(paste0(stat_monthly$year, "-", stat_monthly$month, "-01"),
                    format = "%Y-%m-%d", tz = "UTC")

attr_dates <- array(dates, dim = c(time = length(unique_months),
                                   sdate = length(unique_years)))
attr_dates <- t(attr_dates)
dim(attr_dates) <- c("sdate" = length(unique_years),
                      "time" = length(unique_months))
attr_dates <- as.POSIXct(attr_dates, origin = "1970-01-01", tz = "UTC")

# assign data to the new array #
for (i in seq_along(locations)) {
  # select data for each station #
  # in this case we do not need to filter
  # since we only have data for one station
  
  for (j in seq_along(unique_years)) {
    for (k in seq_along(unique_months)) {
      # get indices in the file for each year and month #
      idx <- which(stat_monthly$year == unique_years[j] &
                     stat_monthly$month == unique_months[k])
      # get indices in the date array for each year and month #
      dates_idx <- which(unique_years[j] == stat_monthly$year &
                           unique_months[k] == stat_monthly$month)
      if (length(idx) > 0) {
        for (var in vars) {
          data_new[1, which(vars == var), j, k, 1, i] <-
            stat_monthly[idx, ][[var]]
        }
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
               sdate = seq_along(unique_years),
               time = seq_along(unique_months),
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
                                        "dados_82791_D_2000-01-01_2025-12-31.csv"))
)
# add the lat/lon as attributes - these could also be added as coordinates
# if desired. Also add the station names as an attribute for reference.
data$attrs$location <- list(latitude = lats, longitude = lons)
data$attrs$station_names <- locations
saveRDS(data, paste0(path_out, "brazil_monthly.rds"))