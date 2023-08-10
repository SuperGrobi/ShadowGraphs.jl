"""
    tag_edge_bearings!(g::AbstractMetaGraph)

calculates the [bearing](https://en.wikipedia.org/wiki/Bearing_(angle)) of each `:sg_street_geometry`
and attaches it to the respective edge as `:ms_bearing`. Helpers and self edges are ignored.
"""
function tag_edge_bearings!(g::AbstractMetaGraph)
    bearings = Float64[]
    lengths = Float64[]
    project_local!(g)
    for e in filter_edges(g, :sg_helper, false)
        if !(get_prop(g, src(e), :sg_helper) && get_prop(g, dst(e), :sg_helper))  # ignores self loops
            set_prop!(g, e, :ms_bearing, single_bearing(get_prop(g, e, :sg_street_geometry)))
        end
    end
    project_back!(g)
    g
end

"""
    single_bearing(line)

calculates the [bearing](https://en.wikipedia.org/wiki/Bearing_(angle)) of a single `ArchGDAL linestring`.
Assumes the line is in a local coordinate system.
"""
function single_bearing(line)
    a = GeoInterface.coordinates(ArchGDAL.pointalongline(line, 0.0))
    b = GeoInterface.coordinates(ArchGDAL.pointalongline(line, ArchGDAL.geomlength(line)))
    return mod(90 - rad2deg(angle(complex((b - a)...))), 360)
end