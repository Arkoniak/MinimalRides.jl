module MinimalRides

using Dates
using Geodesy
using TimeZones
using ZipFile
using ProgressMeter
using CSV
using JSON3
using StructTypes

include("animals.jl")

########################################
# JSON patch
########################################

struct JSONInfo
    id::String
    car_id::String
    category::String
    car_passengers::Int
    cat_carry_weight::Int
    start_dt::String
    end_dt::String
end

struct JSONRide
    info::JSONInfo
    data::Vector{Vector{Float64}}
end
StructTypes.StructType(::Type{JSONInfo}) = StructTypes.Struct()
StructTypes.StructType(::Type{JSONRide}) = StructTypes.Struct()

########################################
# Structures
########################################

struct Location{T}
    ts::Int
    coord::T
end

Location{LatLon{T}}(v::AbstractVector) where T = Location{LatLon{Float64}}(v[1], LatLon{Float64}(v[3], v[2]))
Location(v::AbstractVector{T}) where T = Location{LatLon{T}}(v[1], LatLon{Float64}(v[3], v[2]))
Location{ECEF}(v::AbstractVector{T}, datum = wgs84) where T = Location{ECEF{T}}(v[1], ECEF(LLA(LatLon(v[3], v[2])), datum))
Location{ECEF{T}}(v::AbstractVector, datum = wgs84) where T = Location{ECEF{T}}(v[1], ECEF(LLA(LatLon(v[3], v[2])), datum))
Location{ECEF}(l::Location{LatLon{T}}, datum = wgs84) where T = Location{ECEF{T}}(l.ts, ECEF(LLA(l.coord), datum))

const GEO_RADIUS = 6371.009

function great_circle(p1::LatLon, p2::LatLon)
    lat1, lng1 = deg2rad(p1.lat), deg2rad(p1.lon)
    lat2, lng2 = deg2rad(p2.lat), deg2rad(p2.lon)

    sin_lat1, cos_lat1 = sin(lat1), cos(lat1)
    sin_lat2, cos_lat2 = sin(lat2), cos(lat2)

    delta_lng = lng2 - lng1
    cos_delta_lng, sin_delta_lng = cos(delta_lng), sin(delta_lng)

    d = atan(sqrt((cos_lat2 * sin_delta_lng) ^ 2 + (cos_lat1 * sin_lat2 - sin_lat1 * cos_lat2 * cos_delta_lng) ^ 2), sin_lat1 * sin_lat2 + cos_lat1 * cos_lat2 * cos_delta_lng)

    return GEO_RADIUS * d
end

# this definition twice as fast as native Geodesy version `distance(l1.coord, l2.coord)`
distance(l1::Location{T}, l2::Location{T}) where {T <: LatLon} = great_circle(l1.coord, l2.coord)
distance(l1::Location{T}, l2::Location{T}) where {T <: ECEF} = @inbounds (l1.coord[1] - l2.coord[1])^2 + (l1.coord[2] - l2.coord[2])^2 + (l1.coord[3] - l2.coord[3])^2
# distance(l1::Location, l2::Location) = distance(l1.coord, l2.coord)

struct Info
    id::String
    car_id::String
    category::String
    car_passengers::Int
    cat_carry_weight::Int
    car_type::Symbol
    start_ts::ZonedDateTime
    end_ts::ZonedDateTime
end

function car_type(car)
    res = :other
    res = car.car_passengers >= 8 ? :bus : res

    if (res == :other) & ((car.category == "Специальный\\Автобус ") | (occursin("Легковой", car.category)))
        res = :passenger
    end
    
    res = occursin("Грузовой", car.category) ? :freight : res
    res = car.category == "Строительный\\Автокран" ? :special : res
    # Weird logic, Специальный\\Вахтовая а/м accounted as :bus, not :special
    if (res == :other) & (occursin("Специальный", car.category))
        res = :special
    end

    return res
end

dateformatter() = Dates.DateFormat("yyyy-mm-dd HH:MM:SSzz")

function Info(car)
    Info(
        car.id,
        car.car_id,
        car.category,
        car.car_passengers,
        car.cat_carry_weight,
        car_type(car),
        ZonedDateTime(car.start_dt, dateformatter()),
        ZonedDateTime(car.end_dt, dateformatter())
    )
end

function Info(info::JSONInfo)
    Info(
        info.id,
        info.car_id,
        info.category,
        info.car_passengers,
        info.cat_carry_weight,
        car_type(info),
        ZonedDateTime(info.start_dt, dateformatter()),
        ZonedDateTime(info.end_dt, dateformatter())
    )
end

struct Ride{T}
    info::Info
    route::Vector{Location{T}}
end
Base.getindex(ride::Ride, i) = @inbounds ride.route[i]
Base.length(ride::Ride) = length(ride.route)
Base.lastindex(ride::Ride) = length(ride)

function Ride(ride)
    Ride{LatLon{Float64}}(
        Info(ride.info),
        sort!(Location{LatLon{Float64}}.(ride.data), by = x -> x.ts)
    )
end

function Ride{ECEF}(ride, datum = wgs84)
    Ride{ECEF{Float64}}(
        Info(ride.info),
        sort!(Location{ECEF{Float64}}.(ride.data, datum), by = x -> x.ts)
    )
end

function Ride{ECEF}(ride::Ride{LatLon{T}}, datum = wgs84) where T
    Ride{ECEF{T}}(ride.info, Location{ECEF}.(ride.route))
end

########################################
# Download utility functions
########################################

function load_raw(url, cache, force = false)
    if !isfile(cache) | force
        @info "Downloading rides from $(url)"
        download(url, cache)
    end

    res = JSONRide[]

    r = ZipFile.Reader(cache)
    @info "Processing $(length(r.files)) rides from $(cache)"
    @showprogress for f in r.files
        v = Vector{UInt8}(undef, f.uncompressedsize)
        read!(f, v)
        push!(res, JSON3.read(v, JSONRide))
    end
    close(r)

    return res
end

function load(url, cache, force = false)
    if !isfile(cache) | force
        @info "Downloading rides from $(url)"
        download(url, cache)
    end
    
    res = Ride[]
    r = ZipFile.Reader(cache)
    @info "Processing $(length(r.files)) rides from $(cache)"
    @showprogress for f in r.files
        v = Vector{UInt8}(undef, f.uncompressedsize)
        read!(f, v)
        push!(res, Ride(JSON3.read(v)))
    end
    close(r)
    return identity.(res)
end

########################################
# Simple Ride processing functions 
########################################

function make_subset(rides, days, types)
    filter(x -> (Date(x.info.start_ts) in days) & (x.info.car_type in types), rides)
end

mileage(ride::Ride) = mileage(ride.route)
function mileage(route::AbstractVector{Location{LatLon{T}}}) where T
    res = zero(T)
    @inbounds @simd for i in 2:length(route)
        res += distance(route[i - 1], route[i])
    end

    return res
end

function mileage(route::AbstractVector{Location{ECEF{T}}}) where T
    res = zero(T)
    @inbounds @simd for i in 2:length(route)
        res += sqrt(distance(route[i - 1], route[i]))
    end

    return res/1000
end

########################################
# Smoothing
########################################

abstract type SmoothAlgorithm end

struct DistanceSmoothing <: SmoothAlgorithm
    r::Float64
end

function smooth(alg::DistanceSmoothing, ride::Ride{T}) where {T <: LatLon}
    r = alg.r
    segment = 0.
    route = [ride[1]]
    for i in 2:length(ride)
        segment += distance(ride[i - 1], ride[i])
        if segment >= r
            segment = 0.
            push!(route, ride[i])
        end
    end

    if ride[end] != route[end]
        push!(route, ride[end])
    end

    return Ride(ride.info, route)
end

function smooth(alg::DistanceSmoothing, ride::Ride{T}) where {T <: ECEF}
    r = alg.r*1000
    segment = 0.
    route = [ride[1]]
    for i in 2:length(ride)
        segment += sqrt(distance(ride[i - 1], ride[i]))
        if segment >= r
            segment = 0.
            push!(route, ride[i])
        end
    end

    if ride[end] != route[end]
        push!(route, ride[end])
    end

    return Ride(ride.info, route)
end

struct SegmentSmoothing <: SmoothAlgorithm
    n::Int
end

function smooth(alg::SegmentSmoothing, ride)
    route = ride[1:alg.n:length(ride)]

    if ride[end] != route[end]
        push!(route, ride[end])
    end

    return Ride(ride.info, route)
end

########################################
# Coverage and Results
########################################

function coverage(ride1::Ride{T}, ride2::Ride{T}, radius) where {T <: LatLon}
    dist1 = fill(Inf, length(ride1))
    dist2 = fill(Inf, length(ride2))

    @inbounds for i in 1:length(ride1)
        for j in 1:length(ride2)
            d = distance(ride1[i], ride2[j])
            dist1[i] = d < dist1[i] ? d : dist1[i]
            dist2[j] = d < dist2[j] ? d : dist2[j]
        end
    end

    cov1 = sum(<(radius), dist1)/length(ride1)
    cov2 = sum(<(radius), dist2)/length(ride2)

    return (;cov1, cov2)
end

function coverage(ride1::Ride{T}, ride2::Ride{T}, radius) where {T <: ECEF}
    dist1 = fill(Inf, length(ride1))
    dist2 = fill(Inf, length(ride2))
    radius = (radius * 1000.0)^2

    @inbounds for i in 1:length(ride1)
        for j in 1:length(ride2)
            d = distance(ride1[i], ride2[j])
            dist1[i] = d < dist1[i] ? d : dist1[i]
            dist2[j] = d < dist2[j] ? d : dist2[j]
        end
    end

    cov1 = sum(<(radius), dist1)/length(ride1)
    cov2 = sum(<(radius), dist2)/length(ride2)

    return (;cov1, cov2)
end

function results(rides; smoothalg = DistanceSmoothing(0.5), search_radius = 1.0)
    smooth_rides = smooth.(Ref(smoothalg), rides)
    mileages = mileage.(rides)
    # Too lazy to define new structure, NamedTuple is fine at this stage
    res = NamedTuple{(:i, :j, :cov1, :cov2, :cov, :len1, :len2, :len, :op),Tuple{Int64,Int64,Float64,Float64,Float64,Float64,Float64,Float64,Float64}}[]
    Threads.@threads for i in 1:length(rides)
        for j in i+1:length(rides)
            cov1, cov2 = coverage(smooth_rides[i], smooth_rides[j], search_radius)
            len1 = mileages[i]
            len2 = mileages[j]
            cov = cov1 + cov2
            len = len1 + len2
            op = (cov1 * len1 + cov2 * len2)/(len1 + len2)
            push!(res, (; i, j, cov1, cov2, cov, len1, len2, len, op))
        end
    end

    return res
end

end # module
