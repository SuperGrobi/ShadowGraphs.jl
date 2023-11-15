"""
    pedestrianize!(g::MetaDiGraph)

for every edge in g which has not a reverse edge, adds a reverse edge with
reversed geometry (`:sg_geometry_base` and `sg_street_geometry`) and parsing
direction `:sg_parsing_direction * -1` of the original one. For `:sg_helper`
edges, adds only a key `:sg_helper=true` to the new reverse edge.
"""
function pedestrianize!(g::MetaDiGraph)
    for e in filter_edges(g, :sg_helper, true)
        if !has_edge(g, reverse(e))
            add_edge!(g, dst(e), src(e), :sg_helper, true)
        end
    end
    for e in filter_edges(g, :sg_helper, false)
        if !has_edge(g, reverse(e))
            data = copy(props(g, e))
            data[:sg_parsing_direction] *= -1
            data[:sg_geometry_base] = reverse_geometry(data[:sg_geometry_base])
            data[:sg_street_geometry] = ArchGDAL.clone(data[:sg_geometry_base])
            add_edge!(g, dst(e), src(e), data)
        end
    end
end

"""
    reverse_geometry(geom)

returns a copy of the input linestring with the same `spatialref` but reversed
order of points.
"""
function reverse_geometry(geom)
    crs = ArchGDAL.getspatialref(geom)
    coords = reverse(GeoInterface.coordinates(geom))
    reinterp_crs!(ArchGDAL.createlinestring(coords), crs)
end