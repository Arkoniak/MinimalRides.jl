using Revise
using CSV
using Geodesy
using Dates
using Plots
using StatsPlots
using MinimalRides
using MinimalRides: Pos, load_animal_data

filename = "/media/win/Data/Arctic fox Bylot - GPS tracking.csv"
tracks = load_animal_data(filename);
@assert length(tracks) == 20

length(tracks[1].route)
x = tracks[1].route[3].ts - tracks[1].route[2].ts

arr = map(2:length(tracks[1].route)) do i
    ts2 = tracks[1].route[i].ts
    ts1 = tracks[1].route[i - 1].ts
    p2 = tracks[1].route[i].ecef
    p1 = tracks[1].route[i-1].ecef
    return (seconds = Second(ts2 - ts1).value, dist = distance(p2, p1))
end

sum(x -> x.dist == 0., arr)
findall(x -> x.dist == 0., arr)
findall(x -> x.seconds > 1000., arr)

arr[5590:5610]
x = getfield.(tracks[1].route[2000:4000], :ts)
y = getfield.(arr[2000:4000], :dist)
flt = findall(x -> x > 20.0, y)
plot(x[flt], y[flt])
density(getfield.(arr[2000:4000], :dist))
histogram(getfield.(arr[2000:4000], :dist), bins = 1000)

filter(x -> Date(x.ts) == Date("2019-06-11"), tracks[1].route) |> length
minimum(getfield.(arr[1:349], :dist))
maximum(getfield.(arr[1:349], :seconds))
minimum(getfield.(arr[350:350+357], :dist))
maximum(getfield.(arr[350:350+357], :seconds))


plot(map(x -> (x.ll.lat, x.ll.lon), tracks[1].route))
plot!(map(x -> (x.ll.lat, x.ll.lon), tracks[2].route))
plot!(map(x -> (x.ll.lat, x.ll.lon), tracks[3].route))
plot!(map(x -> (x.ll.lat, x.ll.lon), tracks[4].route))
plot!(map(x -> (x.ll.lat, x.ll.lon), tracks[5].route))
plot!(map(x -> (x.ll.lat, x.ll.lon), tracks[6].route))

names = unique(map(x -> x.info.name_id, tracks))
for name in names
    println(name, ": ", filter(x -> x.info.name_id == name, tracks) |> length)
end

filter(x -> x.info.name_id == "BVOB", tracks)

data = CSV.File(filename);
data[1][Symbol("location-long")]
data[1][Symbol("location-lat")]
DateTime(data[1].timestamp[1:19], "yyyy-mm-dd HH:MM:SS")
data[1]

sort(data, by = x -> (x[Symbol("individual-local-identifier")], x.timestamp))

data[1]
Pos(data[1])
Pos(data[1]).ecef
