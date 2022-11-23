"""
    is_end_node(g, index)

checks if node `index` in graph `g` represents the end of a street (that is, has as most one neighbour).
"""
function is_end_node(g, index)
    from = inneighbors(g, index)
    to = outneighbors(g, index)
    if length(from) == 1 && length(to) == 0
        return true
    elseif length(to) == 1 && length(from) == 0
        return true
    elseif length(to) == 1 && length(from) == 1
        return first(to) == first(from)
    else
        return false
    end
end

"""
    point_on_radius(x, y, r)

returns `x` and `y` coordinates of two random points on a circle with radius `r` around a point given by `x` and `y`.
The two points have a fixed angluar offset of π/3 around the center.
(This function assumes kartesian coordinates and euclidean distances. It is used to gernerate locations of helper nodes).
"""
function point_on_radius(x, y, r)
    ϕ = rand() * 2π
    dx = r * cos.([ϕ, ϕ+π/3])
    dy = r * sin.([ϕ, ϕ+π/3])
    return x.+dx, y.+dy
end

"""
    offset_point_between(g, s, d)

returns `x` and `y` coordinates of a point between nodes `s` and `d` in graph `g`, using the `:lon` and `:lat` properties of the nodes.
the point is (approximately) centered between `s` and `p`, and offset from the centerline by a random distance. 
(Use this function only to generate visually offset point, whose location is not relevant for anything except plotting).
"""
function offset_point_between(g, s, d)
    lat_start = get_prop(g, s, :lat)
    lon_start = get_prop(g, s, :lon)
    lat_dest = get_prop(g, d, :lat)
    lon_dest = get_prop(g, d, :lon)
    delta_lat = (lat_dest-lat_start)
    delta_lon = (lon_dest-lon_start)
    lat_center = (lat_start + lat_dest) / 2
    lon_center = (lon_start + lon_dest) / 2
    scale = 0.5 * rand() + 0.1
    lat_new = lat_center + scale * delta_lon
    lon_new = lon_center - scale * delta_lat
    return lon_new, lat_new
end

"""
    add_edge_with_data!(g, s, d; data=Dict())

adds new edge from `s` to `d` to `g::MetaDiGraph`, and populates it with the `props` given in `data`.

Special care is given to self and multi edges:
- self edges: if `s==d`, actually two new vertices with `props` of `:lat`, `:lon`, `pointgeom` and `:helper=true` are added.
these new vertices (`h1` and `h2`) are then connected to form a loop like: `s --he1--> h1 --real_edge--> h2 --he2--> d`,
where `he1` and `he2` are helper edges with only one `prop` of `:helper=true`. `real_edge` is carrying all the `props` defined
in `data`
- multi edges: if `Edge(s,d) ∈ Edges(g)`, we add one new helper vertex with `props` of `:lat`, `:lon`, `pointgeom` and `:helper=true`.
We connect to the graph like this: `s --he--> h --real_edge--> d`, where `he` is a helper edge with only one `prop`, `:helper=true`.
`real_edge` carries all the `props` specified in `data`

This process is nessecary to preserve the street network topology, since `MetaDiGraph`s do not support multi edges (and therefore also no multi self edges).
"""
function add_edge_with_data!(g, s, d; data=Dict())
    if s == d  # if we are about to add a self-loop
        #@warn "trying to add self loop for node $(get_prop(g, s, :osm_id)) ($s)"
        lat_start = get_prop(g, s, :lat)
        lon_start = get_prop(g, s, :lon)
        lons, lats= point_on_radius(lon_start, lat_start, 0.0003)
        # TODO: add archGDAL point to props
        p1 = ArchGDAL.createpoint(lons[1], lats[1])
        apply_wsg_84!(p1)
        add_vertex!(g, Dict(:lat=>lats[1], :lon=>lons[1], :pointgeom=>p1, :helper=>true))
        id_1 =nv(g)
        add_edge!(g, s, id_1, :helper, true)
        p2 = ArchGDAL.createpoint(lons[2], lats[2])
        apply_wsg_84!(p2)
        add_vertex!(g, Dict(:lat=>lats[2], :lon=>lons[2], :pointgeom=>p2, :helper=>true))
        id_2 = nv(g)
        add_edge!(g, id_2, d, :helper, true)
        add_edge_with_data!(g, id_1, id_2; data=data)
    elseif has_edge(g, s, d)
            #@warn "trying to add multi-edge from node $(get_prop(g, s, :osm_id)) ($s) to $(get_prop(g, d, :osm_id)) ($d)"
            # all of this is bad...
            lon_new, lat_new = offset_point_between(g, s, d)
            p = ArchGDAL.createpoint(lon_new, lat_new)
            apply_wsg_84!(p)
            add_vertex!(g, Dict(:lat=>lat_new, :lon=>lon_new, :pointgeom=>p, :helper=>true))
            add_edge!(g, s, nv(g), :helper, true)
            add_edge_with_data!(g, nv(g), d; data=data)
    else
        for i in [s, d]  # throw consistent errors
            get_prop(g, i, :lon)
            get_prop(g, i, :lat)
        end
        add_edge!(g, s, d)
        for (key, value) in data
            set_prop!(g, s, d, key, value)
        end
    end
end

"""
    is_circular_way(way::Way)

checks if a `LightOSM.Way` way starts at the same node it ends.
"""
is_circular_way(way::Way) = way.nodes[1] == way.nodes[end]

"""
    countall(numbers)

counts how often every number appears in numbers. Returns dict with `number=>count`
"""
countall(numbers) = Dict(number=>count(==(number), numbers) for number in unique(numbers))

"""

    decompose_way_to_primitives(way::Way)

Decomposed a `way` with possible self-intersections/loops into multiple ways which are guaranteed to be either
- non-intersecting lines, where every node in the way is unique, or
- circular ways, where only the first and last node in the way are not unique.

# example
a simple `way` with nodes `[10,20,30,40,50,30]` (which looks like a triangle on a stick, not the repeated `30`) will
be decomposed into two ways, with the nodes `[10,20,30]` and `[30,40,50,30]`.
"""
function decompose_way_to_primitives(way::Way)
    length(way.nodes) <= 1 && throw(ArgumentError("there are less than two nodes in way $(way.id)"))
    nodecounts = countall(way.nodes)
    duplicate_nodes = filter(x->x.second > 1, nodecounts)
    cut_locations = findall(n->n ∈ keys(duplicate_nodes), way.nodes)

    # if nowhere to cut (straight line) or if ring without intersection
    if length(cut_locations) == 0 || cut_locations == [1, length(way.nodes)]
        return [way]
    end

    # from here on, cut_locations is at least one element long
    if cut_locations[1] != 1
        cut_locations = [1; cut_locations]
    end
    if cut_locations[end] != length(way.nodes)
        push!(cut_locations, length(way.nodes))
    end
    # from here, there are at least three cut locations, including start and end point
    sub_nodes = [way.nodes[s:d] for (s, d) in zip(cut_locations[1:end-1], cut_locations[2:end])]
    if is_circular_way(way)
        sub_nodes = [sub_nodes[2:end-1]; [[sub_nodes[end]; sub_nodes[1][2:end]]]]
    end
    return [Way(way.id, nodes, way.tags) for nodes in sub_nodes]
end

"""
    get_neighbor_osm_ids(way::Way, start_id_index, nodes_in_nav_graph)

gets the osm ids of directly connected nodes in the reduced (topological) graph along the `way`.
The starting node from which the neighbour ids are to be calculated is assumed to be at index `start_id_index`
in the array `nodes_in_nav_graph`.

# arguments
- way: `Way` along which the neighbours are situated.
- start_id_index: index of the start node in `nodes_in_nav_graph`
- `nodes_in_nav_graph`: array with osm ids of the nodes which form the `way`, which are also topologically relevant.

# returns
tuple with:
- array of neighbouring osm ids
- array of directions (either `+1` or -1`) that had to be taken from the start index to get to these neighbours
(if you go "along" the `Way` or "against" it).

# notes
While we check if all nodes in `nodes_in_nav_graph` are in the `way`, we do not check if the order is correct.

In addition, we expect the user to take care of the case where the start and end of the `way` are the same node and in the
nav graph. You basically want to get rid of either the start or the end duplicate if they are in the nav graph. If you have 
a `way`:

    ring1 = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring1"))

with the nodes `[10, 30, 60, 80]` in your nav graph, you need to pass only this list and not something like `10, 30, 60, 80, 10]`.

    # correct
    get_neighbor_osm_ids(ring1, 1, [10, 30, 60, 80])  # ([80, 30], [-1, 1])
    get_neighbor_osm_ids(ring1, 1, [30, 60, 80, 10])  # ([10, 60], [-1, 1])

    # danger
    get_neighbor_osm_ids(ring1, 1, [10, 30, 60, 80, 10])  # ([10, 30], [-1, 1])

BUT! If you have a way like

    loli1 = Way(1, [10,20,30,40,50,60,70, 30], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli1"))

you want to preserve the order and the duplicates. For example `[10, 30, 60, 30]`, or, depending on the topology, maybe also `[10, 30, 30]`
    
"""
function get_neighbor_osm_ids(way::Way, start_id_index, nodes_in_nav_graph)
    start_id_index ∉ 1:length(nodes_in_nav_graph) && throw(ArgumentError("the start_id_index $start_id_index is not a valid index of nodes_in_nav_graph ($nodes_in_nav_graph)."))
    for node in nodes_in_nav_graph
        node ∉ way.nodes && throw(ArgumentError("The node $node in nodes_in_nav_graph is not a part of the way (id: $(way.id), nodes: $(way.nodes))"))
    end
    if length(nodes_in_nav_graph) > 1 && nodes_in_nav_graph[1] == nodes_in_nav_graph[end]
        throw(ArgumentError("the beginning of nodes_in_nav_graph is the same as the end. Generally, this is not good. $nodes_in_nav_graph, way_id=$(way.id)"))
    end
    next_osm_ids = []
    used_directions = []
    if way.tags["oneway"]
        step_directions = way.tags["reverseway"] ? [-1] : [1]
    else
        step_directions = [-1, 1]
    end
    for step_direction in step_directions
        next_index = start_id_index + step_direction
        if 1<= next_index <= length(nodes_in_nav_graph)
            push!(next_osm_ids, nodes_in_nav_graph[next_index])
            push!(used_directions, step_direction)
        elseif is_circular_way(way)
            corrected_index = mod(next_index - 1, length(nodes_in_nav_graph)) + 1
            push!(next_osm_ids, nodes_in_nav_graph[corrected_index])
            push!(used_directions, step_direction)
        end
    end
    return next_osm_ids, used_directions
end

"""
    is_lolipop_node(g, osm_id)

checks if the node with `osm_id` is a "lolipop node" in the `LightOSM.OSMGraph` graph. A "lolipop node" is a node which
occurs at the start/end of a way, as well as somewhere in the middle. (For example, the node `1` is considered a "lolipop node""
in the following way: `1-2-3-4-5-1-6-7`)
"""
function is_lolipop_node(g, osm_id)
    ocurrences = []
    is_not_circular = []
    for way_id in g.node_to_way[osm_id]
        way = g.ways[way_id]
        nodes = way.nodes
        ocur_in_way = count(x->x==osm_id, nodes)
        push!(ocurrences, ocur_in_way)
        push!(is_not_circular, !is_circular_way(way))
        ocur_in_way > 2 && @warn "the node $osm_id is contained $ocur_in_way in a way. better check that out..."
    end
    return any(ocurrences .== 2 .&& is_not_circular)
end

"""
    get_node_list(way, start_pos, dest_osm_id, direction)
    
returns a list of all osm node ids between the `start_pos` and the destination node given by `dest_osm_id`,
with step direction of `direction`. If either end of the array is reached during the steps, periodic boundaries
are used.

# arguments
- `way`: `Way` whose nodes should be used
- `start_pos` start index in `way.nodes` (NOT the osm_id of the start node)
- `dest_osm_id` osm id of the destination node
- `direction` direction in which the node list should be steped through in order to find the destination osm id.

# returns
array with osm ids, with start id and destination id at start and end.
"""
function get_node_list(way, start_pos, dest_osm_id, direction)
    direction ∉ [-1, 1] && throw(ArgumentError("direction can only be 1 or -1. (currently: $direction)"))
    if way.tags["oneway"]
        if way.tags["reverseway"] && direction == 1
            throw(ArgumentError("the direction $direction does not match the way (oneway, reverseway)"))
        elseif !way.tags["reverseway"] && direction == -1
            throw(ArgumentError("the direction $direction does not match the way (oneway, normal way)"))
        end
    end
    nodes = way.nodes
    dest_osm_id ∉ nodes && throw(ArgumentError("the destination osm id $dest_osm_id is not in the way ($nodes)"))
    string_nodes = [nodes[start_pos]]
    current_pos = mod(start_pos + direction - 1, length(way.nodes)) + 1
    is_cyclic = is_circular_way(way)
    while nodes[current_pos] != dest_osm_id
        if !is_cyclic
            if direction == 1 && current_pos < start_pos
                throw(ArgumentError("the destination $dest_osm_id can not be reached in the direction of 1 in way $(way.id) from $(way.nodes[start_pos]), with index $start_pos"))
            elseif direction == -1 && current_pos > start_pos
                throw(ArgumentError("the destination $dest_osm_id can not be reached in the direction of -1 in way $(way.id) from $(way.nodes[start_pos]), with index $start_pos"))
            end
        end
        # exclude duplicates where rings close
        if !(way.nodes[current_pos] in string_nodes)
            push!(string_nodes, way.nodes[current_pos])
        end
        current_pos = mod(current_pos + direction - 1, length(way.nodes)) + 1
    end
    push!(string_nodes, way.nodes[current_pos])
    return string_nodes
end

"""
    nodelist_between(way, start_osm_id, dest_osm_id, direction)

builds the list of osm node ids in the way which are between the start and destination osm id (inclusively),
by taking steps through the list of nodes in the direction of `direction`.

If the start osm id occurs twice in the way, the shorter list is returned.
"""
function nodelist_between(way, start_osm_id, dest_osm_id, direction)
    # find start and end index in way.nodes and take everything in between
    start_pos = findall(x->x==start_osm_id, way.nodes)
     
    if length(start_pos) == 1
        start_pos = first(start_pos)
        string_nodes = get_node_list(way, start_pos, dest_osm_id, direction)
    else
        length(start_pos) > 2 && @warn "the start node $start_osm_id apears $(length(start_pos)) times in the way."
        # this assumes, that nodes occure at most twice in every way
        if start_osm_id == dest_osm_id  # if there are loop, take the long way around
            string_nodes = way.nodes[start_pos[1]:start_pos[end]]
        else  # this is for everything else, I assume that if I start from both nodes in the right direction, the shorter path will be the one I want...
            # the longer I think about it, this might actually be generally correct for all cases in this clause, due to the one dimensionality of ways.
            node_lists = [get_node_list(way, start, dest_osm_id, direction) for start in start_pos]
            string_nodes = node_lists[findmin(length, node_lists)[2]]
        end
    end
    return string_nodes
end

"""
    geolinestring(nodes, node_id_list)

creates an `ArchGDAL linestring` from a dictionary mapping osm node ids to `LightOSM.Node` and a list of osm node ids,
representing the nodes of the linestring in order.
"""
function geolinestring(nodes, node_id_list)
    nodelist = [nodes[id] for id in node_id_list]
    location_tuples = [(node.location.lon, node.location.lat) for node in nodelist]
    linestring = ArchGDAL.createlinestring(location_tuples)
    apply_wsg_84!(linestring)
    return linestring
end

"""
    get_rotational_direction(light_osm_graph)

calculates the dominant rotational direction of circular ways in `light_osm_graph`. This can be used to infere
the side of the road on which people in a street network drive.

returns `-1` if the rotation is lefthanded, `1` else. (prints warning if no clear direction could be established).
"""
function get_rotational_direction(light_osm_graph)
    nodes = light_osm_graph.nodes
    ways = light_osm_graph.ways

    rot_dir = 0
    for way in values(ways)
        !is_circular_way(way) && continue  # skip non rings
        node_ids = way.nodes
        points = [nodes[node_id].location for node_id in node_ids[1:end-1]]
        x = [i.lon for i in points]
        y = [i.lat for i in points]
        min_x_ind = findall(e->e==minimum(x), x)

        min_y_options = y[min_x_ind]
        y_ind = argmin(min_y_options)
        ind = min_x_ind[y_ind]

        x_b = x[ind]
        y_b = y[ind]
        ind_low = mod1(ind-1, length(points))
        x_a = x[ind_low]
        y_a = y[ind_low]
        ind_high = mod1(ind+1, length(points))
        x_c = x[ind_high]
        y_c = y[ind_high]

        det = (x_b-x_a)*(y_c - y_a) - (x_c - x_a)*(y_b-y_a)
        if det > 0
            rot_dir += 1
        elseif det < 0
            rot_dir -= 1
        end
    end
    rot_dir == 0 && @warn "not rotational direction could be found. choosing right hand side driving."
    if rot_dir >= 0
        @info "right hand side driving selected"
        return 1
    else
        @info "left hand side driving selected"
        return -1
    end
end

"""
    width(tags)

less opinionated version of the basic parsing `LightOSM` does, to parse the `width` tag of an osm way.
Returns the parsed width if the tag exists or `missing` if not.
"""
function width(tags)
    width = get(tags, "width", missing)
    if width !== missing
        return width isa String ? max([LightOSM.remove_non_numeric(h) for h in split(width, r"[+^;,-]")]...) : width
    else
        return missing
    end
end

"""
    parse_lanes(tags::AbstractDict, tagname)

parses the value of the key `tagname` in `tags`, assuming it to be a numerical value describing a certain number of lanes.
Returns the parsed number of lanes if the tag exists or `missing` if not.
"""
function parse_lanes(tags::AbstractDict, tagname)
    lanes_value = get(tags, tagname, missing)
    U = LightOSM.DEFAULT_OSM_LANES_TYPE

    if lanes_value !== missing
        if lanes_value isa Integer
            return lanes_value
        elseif lanes_value isa AbstractFloat
            return U(round(lanes_value))
        elseif lanes_value isa String 
            lanes_value = split(lanes_value, LightOSM.COMMON_OSM_STRING_DELIMITERS)
            lanes_value = [LightOSM.remove_non_numeric(l) for l in lanes_value]
            return U(round(mean(lanes_value)))
        else
            throw(ErrorException("$tagname is neither a string nor number, check data quality: $lanes_value"))
        end
    else
        return missing
    end
end

"""
    parse_raw_ways(raw_ways, network_type)

parses a list of dicts describing OSM Ways into `LightOSM.Way` instances. This function is a slightly modified version
of the one used in `LightOSM` (`parse_osm_network_dict`), to be able to use our own, non-dafault value assuming parsers
for the labels.

# returns
a dictionary mapping `osm_id` to `LightOSM.Way`
"""
function parse_raw_ways(raw_ways, network_type)
    T = LightOSM.DEFAULT_OSM_ID_TYPE
    ways = Dict{T,Way{T}}()
    for way in raw_ways
        if haskey(way, "tags") && haskey(way, "nodes")
            tags = way["tags"]
            if LightOSM.is_highway(tags) && LightOSM.matches_network_type(tags, network_type)
                tags["oneway"] = LightOSM.is_oneway(tags)
                tags["reverseway"] = LightOSM.is_reverseway(tags)

                tags["width"] = width(tags)

                tags["lanes"] = parse_lanes(tags, "lanes")

                tags["lanes:forward"] = parse_lanes(tags, "lanes:forward")
                tags["lanes:backward"] = parse_lanes(tags, "lanes:backward")
                tags["lanes:both_ways"] = parse_lanes(tags, "lanes:both_ways")

                nds = way["nodes"]
                tags["maxspeed"] = LightOSM.maxspeed(tags)
                id = way["id"]
                ways[id] = Way(id, nds, tags)
            elseif LightOSM.is_railway(tags) && LightOSM.matches_network_type(tags, network_type)
                tags["rail_type"] = get(tags, "railway", "unknown")
                tags["electrified"] = get(tags, "electrified", "unknown")
                tags["gauge"] = get(tags, "gauge", nothing)
                tags["usage"] = get(tags, "usage",  "unknown")
                tags["name"] = get(tags, "name", "unknown")
                tags["lanes"] = get(tags, "tracks", 1)
                tags["maxspeed"] = LightOSM.maxspeed(tags)
                tags["oneway"] = LightOSM.is_oneway(tags)
                tags["reverseway"] = LightOSM.is_reverseway(tags)
                nds = way["nodes"]
                id = way["id"]
                ways[id] = Way(id, nds, tags)
            end
        end
    end
    return ways
end


"""

    add_this_node(g, osm_id)

checks if the node with `osm_id` in graph `g` should be added to the shadow graph. Churrently, we add a node if one of the following is true:
- if the number of ways the node is part of is larger than 1
- if the node is the end of a street, that is, if he has only one neighbour in `g`
- if the node occurs more than once in the way it is part of, excluding the end point, if the way is circular
"""
function add_this_node(g, osm_id)
    index = g.node_to_index[osm_id]
    way_ids = g.node_to_way[osm_id]
    # if the node is part of more than one way
    if length(way_ids) > 1
        return true
    # if the node is the end of a street (has only one neighbour)
    elseif is_end_node(g.graph, index)
        return true
    # if the node appears more than once in the nodes of a way
    # (excluding duplicates caused by circularity)
    else
        way = g.ways[first(way_ids)]  # if there is more than one way, the first if would trigger
        if is_circular_way(way)
            ocurrences = count(==(osm_id), way.nodes[1:end-1])
        else
            ocurrences = count(==(osm_id), way.nodes)                    
        end
        ocurrences > 1 && (return true)
    end
    return false
end


"""
    shadow_graph_from_light_osm_graph(g)

transforms a `LightOSM.OSMGraph` into a `MetaDiGraph`, containing only the topologically relevant
nodes and edges. Attached to every edge and node comes a lot of data, describing this specific edge or node:

# nodes
in the case of helper nodes:
- `:lat`
- `:lon`
- `pointgeom`
- `:helper=true`

in the case of non helper nodes:
- `:osm_id`
- `:lat`
- `:lon`
- `pointgeom`
- `:helper=false`

# edges
in the case of helper edges:
- `:helper=true`

in the case of non helper edges:
- :osm_id
- :tags (tags of the original osm way, with parsed `width`, `lanes`, `lanes:forward`, `lanes:backward` and `lanes:both_ways`, `oneway` and `reverseway` keys)
- :edgegeom (`ArchGDAL linestring` with the geometry of the edge)
- :geomlength=0
- :parsing_direction (direction in which we stepped through the original way nodes to get the linestring)
- :helper=false 
"""
function shadow_graph_from_light_osm_graph(g)
    # make the streets nodes are a part contain only unique elements
    g.node_to_way = Dict(key => unique(value) for (key, value) in g.node_to_way)
    # build clean graph containing only nodes for topologically relevant nodes
    g_nav = MetaDiGraph()

    # add only those nodes, which are part of two or more ways
    for (osm_id, way_ids) in g.node_to_way
        if add_this_node(g, osm_id)
            lat_point = g.nodes[osm_id].location.lat
            lon_point = g.nodes[osm_id].location.lon
            point = ArchGDAL.createpoint(lon_point, lat_point)
            apply_wsg_84!(point)
            data = Dict(
                :(osm_id) => osm_id,
                :lat => lat_point,
                :lon => lon_point,
                :pointgeom => point,
                :helper=>false
            )
            add_vertex!(g_nav, data)
        end
    end

    osm_id_to_nav_id = Dict(get_prop(g_nav, i, :osm_id)=>i for i in vertices(g_nav))
    osm_ids = collect(keys(osm_id_to_nav_id))
    #@showprogress 0.5 "rebuilding topology"
    for start_node_id in vertices(g_nav)
        # get ways this node is part of
        start_osm_id = get_prop(g_nav, start_node_id, :osm_id)
        ways = [g.ways[way_id] for way_id in g.node_to_way[start_osm_id]]
        for way in ways
            nodes_in_nav_graph = [node for node in way.nodes if node in osm_ids]
            all_nodes_in_ng = copy(nodes_in_nav_graph)
            # cut of duplicate node, if the way starts and ends here. (also be carefull of cirlces on a stick.)
            if length(nodes_in_nav_graph) > 1 && nodes_in_nav_graph[1] == nodes_in_nav_graph[end]
                nodes_in_nav_graph = nodes_in_nav_graph[1:end-1]
            end

            start_id_indices = findall(x->x==start_osm_id, nodes_in_nav_graph)
            if length(start_id_indices)!=1 && !is_lolipop_node(g, start_osm_id)
                @warn "the start node $start_osm_id is $(length(start_id_indices)) times in the shortened way."
                @warn all_nodes_in_ng
                @warn "while adding way $(way.id)"
            end

            for start_id_index in start_id_indices
                neighbor_indices, step_directions = get_neighbor_osm_ids(way, start_id_index, nodes_in_nav_graph)
                for (next_osm_id, step_direction) in zip(neighbor_indices, step_directions)
                    next_nav_id = osm_id_to_nav_id[next_osm_id]
                    node_id_list = nodelist_between(way, start_osm_id, next_osm_id, step_direction)
                    linestring = geolinestring(g.nodes, node_id_list)
                    data = Dict(
                        :(osm_id) => way.id,
                        :tags => way.tags,
                        :edgegeom => linestring,
                        :geomlength => 0,
                        :parsing_direction => step_direction,
                        :helper => false
                    )
                    add_edge_with_data!(g_nav, start_node_id, next_nav_id; data=data)
                end
            end
        end
    end

    
    set_prop!(g_nav, :crs, OSM_ref[])
    offset_dir = get_rotational_direction(g)
    set_prop!(g_nav, :offset_dir, offset_dir)
    return g_nav
end

get_raw_ways(osm_json_object::AbstractDict) = LightOSM.osm_dict_from_json(osm_json_object)["way"]
get_raw_ways(osm_xml_object::XMLDocument) = LightOSM.osm_dict_from_xml(osm_xml_object)["way"]

"""
    shadow_graph_from_object(osm_data_object::Union{XMLDocument,Dict}; network_type::Symbol=:drive)

builds the shadow graph from an object holding the raw OSM data. This function is using the `graph_from_object`
function from `LightOSM` to first build a `LightOSM.OSMGraph` object which then gets augmented with the custom parsed
ways, before it gets handed over to the `shadow_graph_from_light_osm_graph` function.

# arguments
- osm_data_object
- network_type: type of network stored in osm_data_object. Options are the same as in `LightOSM`: 
`:drive`, `:drive_service`, `:walk`, `:bike`, `:all`, `:all_private`, `:none`, `:rail`
"""
function shadow_graph_from_object(osm_data_object::Union{XMLDocument,Dict}; network_type::Symbol=:drive)
    raw_ways = deepcopy(get_raw_ways(osm_data_object))
    parsed_ways = parse_raw_ways(raw_ways, network_type)

    g = graph_from_object(osm_data_object;
        network_type=network_type,
        weight_type=:time,
        graph_type=:static,
        precompute_dijkstra_states=false,
        largest_connected_component=true
        )
    for i in keys(g.ways)
        g.ways[i] = parsed_ways[i]
    end

    return shadow_graph_from_light_osm_graph(g)
end

"""
    shadow_graph_from_file(file_path::String; network_type::Symbol=:drive)

builds the shadow graph from a file containing OSM data. The file could have been downloaded with
either `shadow_graph_from_download` or `download_osm_network`.

# arguments
- file_path: path to file. either `.osm`, `.xml` or `.json`
- network_type: type of network stored in file. Options are the same as in `LightOSM`: 
`:drive`, `:drive_service`, `:walk`, `:bike`, `:all`, `:all_private`, `:none`, `:rail`
"""
function shadow_graph_from_file(file_path::String; network_type::Symbol=:drive)
    !isfile(file_path) && throw(ArgumentError("File $file_path does not exist"))
    deserializer = LightOSM.file_deserializer(file_path)
    obj = deserializer(file_path)

    return shadow_graph_from_object(obj; network_type=network_type)
end

"""
    function shadow_graph_from_download(download_method::Symbol;
                                        network_type::Symbol=:drive,
                                        metadata::Bool=false,
                                        download_format::Symbol=:json,
                                        save_to_file_location::Union{String,Nothing}=nothing,
                                        download_kwargs...)

downloads and builds the shadow graph from OSM.

# arguments
- `download_method::Symbol`: Download method, choose from `:place_name`, `:bbox` or `:point`.
- `network_type::Symbol=:drive`: Network type filter, pick from `:drive`, `:drive_service`, `:walk`, `:bike`, `:all`, `:all_private`, `:none`, `:rail`
- `metadata::Bool=false`: Set true to return metadata.
- `download_format::Symbol=:json`: Download format, either `:osm`, `:xml` or `json`.
- `save_to_file_location::Union{String,Nothing}=nothing`: Specify a file location to save downloaded data to disk.

# Required Kwargs for each Download Method

*`download_method=:place_name`*
- `place_name::String`: Any place name string used as a search argument to the Nominatim API.

*`download_method=:bbox`*
- `minlat::AbstractFloat`: Bottom left bounding box latitude coordinate.
- `minlon::AbstractFloat`: Bottom left bounding box longitude coordinate.
- `maxlat::AbstractFloat`: Top right bounding box latitude coordinate.
- `maxlon::AbstractFloat`: Top right bounding box longitude coordinate.

*`download_method=:point`*
- `point::GeoLocation`: Centroid point to draw the bounding box around.
- `radius::Number`: Distance (km) from centroid point to each bounding box corner.

*`download_method=:polygon`*
- `polygon::AbstractVector`: Vector of longitude-latitude pairs.

# Network Types
- `:drive`: Motorways excluding private and service ways.
- `:drive_service`: Motorways including private and service ways.
- `:walk`: Walkways only.
- `:bike`: Cycleways only.
- `:all`: All motorways, walkways and cycleways excluding private ways.
- `:all_private`: All motorways, walkways and cycleways including private ways.
- `:none`: No network filters.
- `:rail`: Railways excluding proposed and platform.

# returns
`MetaDiGraph` with topologically relevant nodes and edges and relevant data attached to every node and edge.
"""
function shadow_graph_from_download(download_method::Symbol;
        network_type::Symbol=:drive,
        metadata::Bool=false,
        download_format::Symbol=:json,
        save_to_file_location::Union{String,Nothing}=nothing,
        download_kwargs...)
    obj = download_osm_network(download_method,
        network_type=network_type,
        metadata=metadata,
        download_format=download_format,
        save_to_file_location=save_to_file_location;
        download_kwargs...)
    return shadow_graph_from_object(obj; network_type=network_type)
end