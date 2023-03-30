"""

    consolidate_nodes_geom(g, radius)

Consolidation of nodes akin to `consolidate_intersections` from `osmnx` (should we just translate that thing into julia? Would be nice...
(Write me a message if you want to get that project started.)), but uses the `:full_length` prop, rather than the geometric distance between nodes.
if there exists an edge between i and j (or j and i) and the  `:full_length` prop of the edge i->j (or j->i) is less than `2*radius`,
then i and j are getting consolidated. This definition is essentially turing every directed edge in a undirected edge, with the minimum of `:full_length`
as a weight. This also means that Nodes which are geographically close, but far apart in street-space are not getting consolidated.

This assumes, that the graph we put in is already simplified in such a way, that the edges only represent meaningful street segments, and not, for
example, a very slowly turning, but non branching curve. (Or think of two nodes splitting one of these streets where going one way is separate
from going the other way, but just by a bit of grass or something.)

Returns `(ids, incoming_lengths, convex_hulls)` where:
- `ids` is a vector of vertex-ids in g, which are closest to the centroids of the sets which are getting consolidated in the
above described fashion. The id is guaranteed to be from the set of ids, which are getting consolidated.
- `incoming_lengths`: array of the sum over the `full_length` props of all the edges inbound to all the consolidated clusters.
For all consolidated sets with 3 or more consolidated points, we return the convex hull of the consolidated set, mainly for visualisation purposes.

"""
function consolidate_nodes_geom(g, radius)
    project_local!(g, get_prop(g, :center_lon), get_prop(g, :center_lat))

    radius *= 2  # because that is what osmnx is doing...
    adj = spzeros(Bool, nv(g), nv(g))
    for v in vertices(g)
        in_edges = Edge.(inneighbors(g, v), v)
        out_edges = Edge.(v, outneighbors(g, v))
        for e in [in_edges; out_edges]
            street_length = has_prop(g, e, :full_length) ? get_prop(g, e, :full_length) : 0.0
            if street_length < radius
                adj[src(e), dst(e)] = true
                adj[dst(e), src(e)] = true
            end
        end
    end
    components = connected_components(SimpleGraph(adj))
    closest_ids = Int[]
    incoming_edges = []
    incoming_lengths = Float64[]
    convex_hulls = []
    for consolidation_ids in components
        if length(consolidation_ids) == 1
            id = first(consolidation_ids)
            total_length = sum(inneighbors(g, id); init=0.0) do v
                if has_prop(g, v, id, :full_length)
                    get_prop(g, v, id, :full_length)
                else
                    0.0
                end
            end
        else
            points_to_consolidate = get_points_to_consolidate(g, consolidation_ids)
            centroid = ArchGDAL.centroid(points_to_consolidate)
            if length(consolidation_ids) >= 3
                conv_hull = ArchGDAL.convexhull(points_to_consolidate)
                push!(convex_hulls, ArchGDAL.buffer(conv_hull, radius / 2, 5))
            end
            id = get_closest_id(g, centroid, consolidation_ids)
            total_length = get_inbound_lengths(g, consolidation_ids)
        end
        push!(incoming_edges, get_inbound_edges(g, consolidation_ids))
        push!(closest_ids, id)
        push!(incoming_lengths, total_length)
    end
    project_back!(g)
    length(convex_hulls) > 0 && project_back!(convex_hulls)
    return closest_ids, incoming_edges, incoming_lengths, convex_hulls
end


"""

    get_points_to_consolidate(g, ids) 
    
converts the node locations of the nodes with id `ids` in `g` to an `ArchGDAL.multipoint`.
"""
function get_points_to_consolidate(g, ids)
    points_to_consolidate = ArchGDAL.createmultipoint()
    reinterp_crs!(points_to_consolidate, get_prop(g, :crs))
    for v in ids
        ArchGDAL.addgeom!(points_to_consolidate, get_prop(g, v, :pointgeom))
    end
    return points_to_consolidate
end

"""

    get_closest_id(g, centroid, ids)

gets the id of node-`ids` in `g`, that is located closest to the `centroid`.
"""
function get_closest_id(g, centroid, ids)
    min_data = findmin(ids) do v
        point = get_prop(g, v, :pointgeom)
        ArchGDAL.distance(centroid, point)
    end
    return ids[min_data[2]]
end

"""

    get_inbound_lengths(g, ids)

returns the sum of the `:full_length` props of all edges which enter the cluster of nodes given by `id`.
This might sometimes underestimate the real full length, when the entering edge is a helper edge. In that
case, this edge gets a weight of 0.0. We could fix this problem by making the destination of the non-helper
edge always a non-helper node, and placing the helper nodes on top of their respective sources. (#TODO).
That way we can never "cut" a cluster along the helper edges and get a length of zero. Or we somehow move up (or down?)
the string of helpers to find the correct edge. This is not very nice to implement, the former option will
destroy all ploting we have left, and both will probably not change the results too much. So for now we have to live with
that problem. 
"""
function get_inbound_lengths(g, ids)
    sum(ids) do id
        inns = filter(i -> !(i in ids), inneighbors(g, id))
        sum(inns, init=0.0) do s
            if has_prop(g, s, id, :full_length)
                get_prop(g, s, id, :full_length)
            else
                0.0
            end
        end
    end
end


function get_inbound_edges(g, ids)
    mapreduce(vcat, ids) do id
        inns = filter(i -> !(i in ids), inneighbors(g, id))
        return Edge.(inns, id)
    end
end

"""

    consolidate_nodes_geom_slow(g, radius)

slow not exactly the same function as `consolidate_nodes_geom`. This implementation is heavily inspired
by `consolidate_intersections` from `osmnx`, whereas `consolidate_nodes_geom` uses a different approach.
Funnily, this function gets faster for large buffer radii, while `consolidate_nodes_geom` gets fast for
smaller radii.
This function is more or less legacy code, but nice to have for testing, to validate the results from `consolidate_nodes_geom`.
"""
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