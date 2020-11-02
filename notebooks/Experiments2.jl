using Revise
using Geodesy
using MinimalRides
using Dates
using MinimalRides: make_subset, DistanceSmoothing, results, mileage, smooth, load_raw, Ride
using DataFrames
using Underscores
using BenchmarkTools

x = LatLon(-27.468937, 153.023628)
ECEF(LLA(x), wgs84)[1]
ECEF(x, wgs84)[1]

origin = [1, 153.023628, -27.468937] # City Hall, Brisbane, Australia
point = [2, 153.025900, -27.465933]  # Central Station, Brisbane, Australia

v = [1234, 153.023628, -27.468937]
MinimalRides.Location{ECEF}(MinimalRides.Location(v))

p1 = MinimalRides.Location(origin)
p1a = MinimalRides.Location{ECEF}(origin)
p2 = MinimalRides.Location(point)
p2a = MinimalRides.Location{ECEF}(point)

MinimalRides.distance(p1, p2) * 1000  # 402.27127280646783
sqrt(MinimalRides.distance(p1a, p2a)) # 401.5431022017651

using BenchmarkTools
@benchmark MinimalRides.distance($p1, $p2)
# BenchmarkTools.Trial:
#   memory estimate:  0 bytes
#   allocs estimate:  0
#   --------------
#   minimum time:     44.489 ns (0.00% GC)
#   median time:      45.148 ns (0.00% GC)
#   mean time:        48.273 ns (0.00% GC)
#   maximum time:     629.762 ns (0.00% GC)
#   --------------
#   samples:          10000
#   evals/sample:     990

@benchmark MinimalRides.distance(Ref($p1a)[], Ref($p2a)[])
# BenchmarkTools.Trial:
#   memory estimate:  0 bytes
#   allocs estimate:  0
#   --------------
#   minimum time:     1.599 ns (0.00% GC)
#   median time:      1.615 ns (0.00% GC)
#   mean time:        1.680 ns (0.00% GC)
#   maximum time:     23.345 ns (0.00% GC)
#   --------------
#   samples:          10000
#   evals/sample:     1000

########################################
# JSON load test
########################################
url = "https://github.com/epogrebnyak/rides-minimal/blob/master/sample_jsons/sample_jsons.zip?raw=true"
cache = "/tmp/sample_json.zip"
load_raw(url, cache);

########################################
# LatLon to ECEF conversion
########################################
RAW_DATA_URL_UPDATED = ("https://dl.dropboxusercontent.com" *
    "/sh/hibzl6fkzukltk9/AABSMicBJlwMnlmA3ljt1uY5a" *
    "/data_samples-json2.zip")
CACHE_DATA = "/media/win/Data/data_samples-json2.zip"

rides = load_raw(RAW_DATA_URL_UPDATED, CACHE_DATA) .|> Ride;
rides_ecef = Ride{ECEF}.(rides);

@benchmark MinimalRides.Ride{ECEF}.($rides)

DAYS = Date.(["2020-05-21"])
TYPES = [:freight]

subset = make_subset(rides, DAYS, TYPES)

subset_ecef = make_subset(rides_ecef, DAYS, TYPES)
map(x -> x.info.id, subset) == map(x -> x.info.id, subset_ecef) # Sanity check


mileage(rides[10])
mileage(rides_ecef[10])

@benchmark mileage($rides[10])
# BenchmarkTools.Trial:
#   memory estimate:  0 bytes
#   allocs estimate:  0
#   --------------
#   minimum time:     275.165 μs (0.00% GC)
#   median time:      277.340 μs (0.00% GC)
#   mean time:        295.902 μs (0.00% GC)
#   maximum time:     2.431 ms (0.00% GC)
#   --------------
#   samples:          10000
#   evals/sample:     1
@benchmark mileage($rides_ecef[10])
# BenchmarkTools.Trial:
#   memory estimate:  0 bytes
#   allocs estimate:  0
#   --------------
#   minimum time:     6.500 μs (0.00% GC)
#   median time:      6.909 μs (0.00% GC)
#   mean time:        8.071 μs (0.00% GC)
#   maximum time:     22.354 μs (0.00% GC)
#   --------------
#   samples:          10000
#   evals/sample:     5

smooth(DistanceSmoothing(0.5), rides[10]) |> length
smooth(DistanceSmoothing(0.5), rides_ecef[10]) |> length

@benchmark smooth(DistanceSmoothing(0.5), $rides[10])
# BenchmarkTools.Trial:
#   memory estimate:  24.53 KiB
#   allocs estimate:  10
#   --------------
#   minimum time:     290.215 μs (0.00% GC)
#   median time:      295.307 μs (0.00% GC)
#   mean time:        313.093 μs (0.00% GC)
#   maximum time:     2.755 ms (0.00% GC)
#   --------------
#   samples:          10000
#   evals/sample:     1
@benchmark smooth(DistanceSmoothing(0.5), $rides_ecef[10])
# BenchmarkTools.Trial:
#   memory estimate:  32.50 KiB
#   allocs estimate:  10
#   --------------
#   minimum time:     14.488 μs (0.00% GC)
#   median time:      15.557 μs (0.00% GC)
#   mean time:        17.449 μs (3.25% GC)
#   maximum time:     5.704 ms (99.40% GC)
#   --------------
#   samples:          10000
#   evals/sample:     1

df = results(subset; smoothalg = DistanceSmoothing(0.5), search_radius = 2.5 * 1.2) |> DataFrame
pairs_df = @_ sort(df, :op, rev = true) |> filter((_.op > 0.75) & (_.len > 400), __)
@benchmark(results($subset))
# BenchmarkTools.Trial:
#   memory estimate:  3.45 MiB
#   allocs estimate:  1721
#   --------------
#   minimum time:     1.008 s (0.00% GC)
#   median time:      1.036 s (0.00% GC)
#   mean time:        1.036 s (0.00% GC)
#   maximum time:     1.061 s (0.00% GC)
#   --------------
#   samples:          5
#   evals/sample:     1

df_ecef = results(subset_ecef; smoothalg = DistanceSmoothing(0.5), search_radius = 2.5 * 1.2) |> DataFrame
pairs_df_ecef = @_ sort(df_ecef, :op, rev = true) |> filter((_.op > 0.75) & (_.len > 400), __)
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
