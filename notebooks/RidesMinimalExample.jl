using MinimalRides
using Plots
using DataFrames
using Dates
using Underscores

import MinimalRides: make_subset, results, DistanceSmoothing

RAW_DATA_URL_UPDATED = ("https://dl.dropboxusercontent.com" *
    "/sh/hibzl6fkzukltk9/AABSMicBJlwMnlmA3ljt1uY5a" *
    "/data_samples-json2.zip")
CACHE_DATA = "/media/win/Data/data_samples-json2.zip"

rides = MinimalRides.load(RAW_DATA_URL_UPDATED, CACHE_DATA);

DAYS = Date.(["2020-05-21"])
TYPES = [:freight]

subset = make_subset(rides, DAYS, TYPES)

df = results(subset; smoothalg = DistanceSmoothing(0.5), search_radius = 2.5 * 1.2) |> DataFrame

pairs_df = @_ sort(df, :op, rev = true) |> filter((_.op > 0.75) & (_.len > 400), __)

println("Best pairs: ")
println(pairs_df)

for i in axes(pairs_df, 1)
    plot(map(x -> (x.coord.lat, x.coord.lon), subset[pairs_df[i, :i]].route), 
        title = "Rides ($(pairs_df[i, :i]), $(pairs_df[i, :j]))",
        label = "Ride $(pairs_df[i, :i])")
    d = plot!(map(x -> (x.coord.lat, x.coord.lon), subset[pairs_df[i, :j]].route),
        label = "Ride $(pairs_df[i, :j])")
    display(d)
end

using BenchmarkTools

# 37 routes, 666 (37*36/2) pairs
println("Benchmark results: ")
show(stdout, MIME"text/plain"(), @benchmark(results($subset)))
