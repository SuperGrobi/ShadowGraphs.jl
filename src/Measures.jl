function tag_edge_bearings!(g::AbstractMetaGraph)
    bearings = Float64[]
    lengths = Float64[]
    project_local!(g)
    for e in filter_edges(g, :helper, false)
        if !(get_prop(g, src(e), :helper) && get_prop(g, dst(e), :helper))
            set_prop!(g, e, :bearing, single_bearing(get_prop(g, e, :edgegeom)))
        end
    end
    project_back!(g)
    g
end

function single_bearing(line)
    a = ArchGDAL.pointalongline(line, 0.0) |> getcoord |> collect
    b = ArchGDAL.pointalongline(line, ArchGDAL.geomlength(line)) |> getcoord |> collect
    return angle(complex((b - a)...) * (-π / 2 * im))
end