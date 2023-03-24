"""

    consolidate_nodes_geom(g, radius)

Consolidation of nodes akin to `consolidate_intersections` from `osmnx` (should we just translate that thing into julia? Would be nice...
(Write me a message if you want to get that project started.))
if circle with `radius` around node i overlaps circle with `radius` around node j, then i and j are getting consolidated.

Returns `(ids, convex_hulls)`

where `ids` is a vector of vertex-ids in g, which are closest to the centroids of the sets which are getting consolidated in the
above described fashion. The id is guaranteed to be from the set of ids, which are getting consolidated.

For all consolidated sets with 3 or more consolidated points, we return the convex hull of the consolidated set, mainly for visualisation purposes.
"""
function consolidate_nodes_geom(g, radius)
    project_local!(g, get_prop(g, :center_lon), get_prop(g, :center_lat))

    radius *= 2  # because that is what osmnx is doing...
    rt = build_point_rtree((get_prop(g, v, :pointgeom) for v in vertices(g)), vertices(g), true)
    adj = spzeros(Bool, nv(g), nv(g))
    for v in vertices(g)
        intersections_square = @chain v get_prop(g, _, :pointgeom) rect_from_geom(buffer=radius) intersects_with(rt, _)
        for neigh in intersections_square
            if v != neigh.val.data && ArchGDAL.distance(get_prop(g, v, :pointgeom), neigh.val.pointgeom) <= radius
                adj[v, neigh.val.data] = true
            end
        end
    end
    components = connected_components(SimpleGraph(adj))
    convex_hulls = []
    closest_ids = map(components) do consolidation_ids
        if length(consolidation_ids) == 1
            id = first(consolidation_ids)
            return id
        else
            points_to_consolidate = get_points_to_consolidate(g, consolidation_ids)
            centroid = ArchGDAL.centroid(points_to_consolidate)
            if length(consolidation_ids) >= 3
                # maps mutating state. This is not what curry intended.
                push!(convex_hulls, ArchGDAL.convexhull(points_to_consolidate))
            end
            return get_closest_id(g, centroid, consolidation_ids)
        end
    end
    project_back!(g)
    return closest_ids, convex_hulls
end

function get_points_to_consolidate(g, ids)
    points_to_consolidate = ArchGDAL.createmultipoint()
    reinterp_crs!(points_to_consolidate, get_prop(g, :crs))
    for v in ids
        ArchGDAL.addgeom!(points_to_consolidate, get_prop(g, v, :pointgeom))
    end
    return points_to_consolidate
end

function get_closest_id(g, centroid, ids)
    min_data = findmin(ids) do v
        point = get_prop(g, v, :pointgeom)
        ArchGDAL.distance(centroid, point)
    end
    return ids[min_data[2]]
end


function consolidate_nodes_geom_slow(g, radius)
    project_local!(g, get_prop(g, :center_lon), get_prop(g, :center_lat))
    bufferzones = ArchGDAL.buffer.((get_prop(g, v, :pointgeom) for v in vertices(g)), radius, 30)
    consolidation_zones = foldl(ArchGDAL.union, bufferzones)
    consolidation_points = []
    consolidation_ids = []
    for area in getgeom(consolidation_zones)
        points_in_area = ArchGDAL.createmultipoint()
        point_ids = Int[]
        foreach(vertices(g)) do v
            point = get_prop(g, v, :pointgeom)
            if ArchGDAL.contains(area, point)
                ArchGDAL.addgeom!(points_in_area, point)
                push!(point_ids, v)
            end
        end
        push!(consolidation_points, points_in_area)
        push!(consolidation_ids, point_ids)
    end
    centroids = ArchGDAL.centroid.(consolidation_points)
    closest_indices = map(centroids, consolidation_ids) do centroid, ids
        min_data = findmin(ids) do v
            point = get_prop(g, v, :pointgeom)
            ArchGDAL.distance(centroid, point)
        end
        return ids[min_data[2]]
    end
    project_back!(g)
    return consolidation_zones, consolidation_points, closest_indices, centroids
end