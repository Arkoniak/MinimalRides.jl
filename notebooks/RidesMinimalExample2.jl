using MinimalRides
using Plots
using DataFrames
using Dates
using Geodesy
using Underscores

import MinimalRides: make_subset, results, DistanceSmoothing

########################################
# Data loading
########################################

RAW_DATA_URL_UPDATED = ("https://dl.dropboxusercontent.com" *
    "/sh/hibzl6fkzukltk9/AABSMicBJlwMnlmA3ljt1uY5a" *
    "/data_samples-json2.zip")
CACHE_DATA = "/media/win/Data/data_samples-json2.zip"

rides = MinimalRides.load(RAW_DATA_URL_UPDATED, CACHE_DATA);
rides_ecef = MinimalRides.Ride{ECEF}.(rides)

########################################
# Data sampling
########################################

DAYS = Date.(["2020-05-21"])
TYPES = [:freight]

subset = make_subset(rides, DAYS, TYPES)
subset_ecef = make_subset(rides_ecef, DAYS, TYPES)

# Sanity check
@assert map(x -> x.info.id, subset) == map(x -> x.info.id, subset_ecef)

########################################
# Main calculations
########################################

df_ecef = results(subset_ecef; smoothalg = DistanceSmoothing(0.5), search_radius = 2.5 * 1.2) |> DataFrame
pairs_df_ecef = @_ sort(df_ecef, :op, rev = true) |> filter((_.op > 0.75) & (_.len > 400), __)

for i in axes(pairs_df_ecef, 1)
    plot(map(x -> (x.coord.lat, x.coord.lon), subset[pairs_df_ecef[i, :i]].route), 
        title = "Rides ($(pairs_df_ecef[i, :i]), $(pairs_df_ecef[i, :j]))",
        label = "Ride $(pairs_df_ecef[i, :i])")
    d = plot!(map(x -> (x.coord.lat, x.coord.lon), subset[pairs_df_ecef[i, :j]].route),
        label = "Ride $(pairs_df_ecef[i, :j])")
    display(d)
end

########################################
# Sanity check
########################################

df = results(subset; smoothalg = DistanceSmoothing(0.5), search_radius = 2.5 * 1.2) |> DataFrame

pairs_df = @_ sort(df, :op, rev = true) |> filter((_.op > 0.75) & (_.len > 400), __)

println("LatLon algorithm: ")
println(pairs_df)
println("ECEF algorithm: ")
println(pairs_df_ecef)

########################################
# Benchmarking
########################################

@benchmark(results($subset_ecef))
# BenchmarkTools.Trial:
#   memory estimate:  3.65 MiB
#   allocs estimate:  1721
#   --------------
#   minimum time:     41.444 ms (0.00% GC)
#   median time:      43.135 ms (0.00% GC)
#   mean time:        43.243 ms (0.00% GC)
#   maximum time:     50.773 ms (0.00% GC)
#   --------------
#   samples:          116
#   evals/sample:     1
