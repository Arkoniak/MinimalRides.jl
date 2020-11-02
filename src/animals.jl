struct Pos
    ts::DateTime
    event_id::Int
    visible::Bool
    ll::LatLon{Float64}
    ecef::ECEF{Float64}
end

function Pos(row, datum = wgs84)
    ts = DateTime(row.timestamp[1:19], "yyyy-mm-dd HH:MM:SS")
    lat = row[Symbol("location-lat")]
    lon = row[Symbol("location-long")]
    ismissing(lat) | ismissing(lon) && return nothing
    ll = LatLon{Float64}(lat, lon)
    ecef = ECEF(LLA(ll), datum)

    return Pos(ts, row[Symbol("event-id")], row.visible, ll, ecef)
end

struct AnimalInfo
    taxon_canonical_name::String
    # tag_id::Int
    name_id::String
end

struct Track
    info::AnimalInfo
    route::Vector{Pos}
end

function load_animal_data(filename, datum = wgs84)
    data = CSV.File(filename)
    data = sort(data, by = x -> (x[Symbol("individual-local-identifier")], x.timestamp))
    tracks = Track[]
    taxon = ""
    name_id = ""
    # tag_id = -1
    route = Pos[]
    for row in data
        taxon2 = row[Symbol("individual-taxon-canonical-name")]
        name_id2 = row[Symbol("individual-local-identifier")]
        # tag_id2 = row[Symbol("tag-local-identifier")]
        # if (taxon != taxon2) | (name_id2 != name_id) | (tag_id2 != tag_id)
        if (taxon != taxon2) | (name_id2 != name_id)
            taxon, name_id = taxon2, name_id2
            info = AnimalInfo(taxon, name_id)
            route = Pos[]
            push!(tracks, Track(info, route))
        end
        pos = Pos(row, datum)
        if !isnothing(pos)
            push!(route, Pos(row, datum))
        end
    end

    return tracks
end
