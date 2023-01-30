"""
    width(tags)

less opinionated version of the basic parsing `LightOSM` does, to parse the `width` tag of an osm way.
Returns the parsed width if the tag exists or `missing` if not.If Values are negative, we take the absolute value.
"""
function width(tags)
    width = get(tags, "width", missing)
    if width !== missing
        if !(width isa Number)
            width = max([LightOSM.remove_non_numeric(h) for h in split(width, r"[+^;,-]")]...)
        end
        return abs(width)
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
            return abs(lanes_value)
        elseif lanes_value isa AbstractFloat
            return U(abs(round(lanes_value)))
        elseif lanes_value isa String
            lanes_value = split(filter(!=('-'), lanes_value), LightOSM.COMMON_OSM_STRING_DELIMITERS)
            lanes_value = [LightOSM.remove_non_numeric(l) for l in lanes_value]
            return U(abs(round(mean(lanes_value))))
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
                tags["usage"] = get(tags, "usage", "unknown")
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
    add_edge_with_data!(g, s, d; data=Dict())

adds new edge from `s` to `d` to `g::MetaDiGraph`, and populates it with the `props` given in `data`.

`data` is expected to have at least a key `:edgegeom`, containing the geometry of the street between `s` and `d` as an `ArchGDAL linestring` in the WSG84
system. (Use `apply_wsg_84!`)

Special care is given to self and multi edges:
- self edges: if `s==d`, actually two new vertices are added at 10% and 60% along the `:edgegeom`, with `props` of `:lat`, `:lon`, `pointgeom` and `:helper=true` set acordingly.
These new vertices (`h1` and `h2`) are then connected to form a loop like: `s --he1--> h1 --real_edge--> h2 --he2--> d`,
where `he1` and `he2` are helper edges with only one `prop` of `:helper=true`. `real_edge` is carrying all the `props` defined
in `data`
- multi edges: if `Edge(s,d) ∈ Edges(g)`, we add one new helper vertex at 50% along the `:edgegeom` with `props` of `:lat`, `:lon`, `pointgeom` and `:helper=true`.
We connect to the graph like this: `s --he--> h --real_edge--> d`, where `he` is a helper edge with only one `prop`, `:helper=true`.
`real_edge` carries all the `props` specified in `data`

This process is nessecary to preserve the street network topology, since `MetaDiGraph`s do not support multi edges (and therefore also no multi self edges).
"""
function add_edge_with_data!(g, s, d; data=Dict())
    !haskey(data, :edgegeom) && throw(KeyError("cant add edge, data has no key :edgegeom."))

    if s == d  # if we are about to add a self-loop
        #@warn "trying to add self loop for node $(get_prop(g, s, :osm_id)) ($s)"
        geomlength = ArchGDAL.geomlength(data[:edgegeom])

        p1 = ArchGDAL.pointalongline(data[:edgegeom], 0.1 * geomlength)
        apply_wsg_84!(p1)
        add_vertex!(g, Dict(:lon => ArchGDAL.getx(p1, 0), :lat => ArchGDAL.gety(p1, 0), :pointgeom => p1, :helper => true))

        id_1 = nv(g)
        add_edge!(g, s, id_1, :helper, true)

        p2 = ArchGDAL.pointalongline(data[:edgegeom], 0.6 * geomlength)
        apply_wsg_84!(p2)
        add_vertex!(g, Dict(:lon => ArchGDAL.getx(p2, 0), :lat => ArchGDAL.gety(p2, 0), :pointgeom => p2, :helper => true))
        id_2 = nv(g)
        add_edge!(g, id_2, d, :helper, true)

        add_edge_with_data!(g, id_1, id_2; data=data)
    elseif has_edge(g, s, d)
        #@warn "trying to add multi-edge from node $(get_prop(g, s, :osm_id)) ($s) to $(get_prop(g, d, :osm_id)) ($d)"
        # all of this is bad...
        p = ArchGDAL.pointalongline(data[:edgegeom], 0.5 * ArchGDAL.geomlength(data[:edgegeom]))
        apply_wsg_84!(p)
        add_vertex!(g, Dict(:lon => ArchGDAL.getx(p, 0), :lat => ArchGDAL.gety(p, 0), :pointgeom => p, :helper => true))
        add_edge!(g, s, nv(g), :helper, true)
        add_edge_with_data!(g, nv(g), d; data=data)
    else
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
countall(numbers) = Dict(number => count(==(number), numbers) for number in unique(numbers))


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
    duplicate_nodes = filter(x -> x.second > 1, nodecounts)
    cut_locations = findall(n -> n ∈ keys(duplicate_nodes), way.nodes)

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

    get_rotational_direction(way::Way, nodes, direction)

calculates the direction of rotation of the way if walked through in the direction of `direction` (either 1 or -1).
Since the node locations are stored seperately, you have to pass in a dict `node_id=>LightOSM.Node` seperately. Used only on simplified ways.

# Returns
- `1` if the rotation is righthanded
- `-1` if the rotation is lefthanded
- `0` if the way is not closed
"""
function get_rotational_direction(way::Way, nodes, direction)
    !is_circular_way(way) && return 0  # non rings do not rotate
    node_ids = way.nodes
    points = [nodes[node_id].location for node_id in node_ids[1:end-1]]
    x = [i.lon for i in points]
    y = [i.lat for i in points]
    min_x_ind = findall(e -> e == minimum(x), x)

    min_y_options = y[min_x_ind]
    y_ind = argmin(min_y_options)
    ind = min_x_ind[y_ind]

    x_b = x[ind]
    y_b = y[ind]
    ind_low = mod1(ind - 1, length(points))
    x_a = x[ind_low]
    y_a = y[ind_low]
    ind_high = mod1(ind + 1, length(points))
    x_c = x[ind_high]
    y_c = y[ind_high]

    det = (x_b - x_a) * (y_c - y_a) - (x_c - x_a) * (y_b - y_a)
    if det > 0
        return 1 * direction
    elseif det < 0
        return -1 * direction
    else
        return 0
    end
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

    get_node_list(simple_way, start_osm_id, topological_nodes, direction) 

tries to get list of osm ids in `simple_way` between the start_osm_id and the next topologically relevant node in direction of `direction`.
Returns either `Int[]` or `nothing` if there is no relevant node in direction of `direction`.

Used only on simplified ways.
"""
function get_node_list(simple_way, start_osm_id, topological_nodes, direction)
    direction ∉ [-1, 1] && throw(ArgumentError("direction $direction not allowed"))

    all_nodes = simple_way.nodes

    start_osm_id ∉ all_nodes && throw(ArgumentError("start_osm_id $start_osm_id not in way.nodes: $all_nodes"))
    start_osm_id ∉ topological_nodes && throw(ArgumentError("start_osm_id $start_osm_id not in topological_nodes: $topological_nodes"))
    any([n ∉ all_nodes for n in topological_nodes]) && throw(ArgumentError("not all topological nodes ($topological_nodes) are in the original way ($all_nodes)!"))

    large_counts = filter(p -> p.second > 1, countall(all_nodes))
    length(large_counts) > 1 && throw(ArgumentError("You input a non simple way (nodes: $all_nodes)"))

    if length(large_counts) == 1
        prob_node = first(first(large_counts))
        if !(prob_node == all_nodes[1] && prob_node == all_nodes[end])
            throw(ArgumentError("You input a non simple, non cyclic way (nodes: $all_nodes)"))
        end
    end

    # get index of start node in full and in reduced nodes list
    all_start_index = direction == 1 ? findfirst(==(start_osm_id), all_nodes) : findlast(==(start_osm_id), all_nodes)
    topological_start_index = direction == 1 ? findfirst(==(start_osm_id), topological_nodes) : findlast(==(start_osm_id), topological_nodes)
    topological_destination_index = topological_start_index + direction

    # in every simple way, at most the the start and end node are the same
    if is_circular_way(simple_way) # start and end node are the same
        destination_osm_id = topological_nodes[mod1(topological_destination_index, length(topological_nodes))]
        all_destination_index = direction == -1 ? findfirst(==(destination_osm_id), all_nodes) : findlast(==(destination_osm_id), all_nodes)
        # correct destination due to periodic boundary
        if direction == 1 && all_start_index >= all_destination_index
            all_destination_index += length(all_nodes)
        elseif direction == -1 && all_start_index <= all_destination_index
            all_start_index += length(all_nodes)
        end
        indices = mod1.(all_start_index:direction:all_destination_index, length(all_nodes))

        nodelist_inbetween = all_nodes[mod1.(all_start_index:direction:all_destination_index, length(all_nodes))]
        return rle(nodelist_inbetween)[1]
    else # everything is unique, nothing is periodic
        try
            destination_osm_id = topological_nodes[topological_start_index+direction]
            all_destination_index = findfirst(==(destination_osm_id), all_nodes)
            nodelist_inbetween = all_nodes[all_start_index:direction:all_destination_index]
            return nodelist_inbetween
        catch e
            e isa BoundsError ? (return nothing) : rethrow(e)
        end
    end
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
- `:osm_id`
- `:tags` (tags of the original osm way, with parsed `width`, `lanes`, `lanes:forward`, `lanes:backward` and `lanes:both_ways`, `oneway` and `reverseway` keys)
- `:edgegeom_base` (`ArchGDAL linestring` with the geometry of the edge. Should not be modified during subsequent operations.)
- `:edgegeom` (copy of `:edgegeom_base`. This one will be modified during offsetting and such.)
- `:full_length` (length of `edgegeom` in a projected crs)
- `:parsing_direction` (direction in which we stepped through the original way nodes to get the linestring)
- `:helper`=false 
the props '[:osm_id, :tags, :edgegeom_base, :parsing_direction, :helper] are considered read-only.
(Editing them might cause strange behaviour. Always duplicate the `:edgegeom_base` with `ArchGDAL.clone`)
"""
function shadow_graph_from_light_osm_graph(g)
    # make the streets nodes are a part contain only unique elements
    g.node_to_way = Dict(key => unique(value) for (key, value) in g.node_to_way)
    # build clean graph containing only nodes for topologically relevant nodes
    g_nav = MetaDiGraph()
    defaultweight!(g_nav, 0.0)
    weightfield!(g_nav, :full_length)
    # add only those nodes, which are relevant for topology
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
                :helper => false
            )
            add_vertex!(g_nav, data)
        end
    end

    osm_id_to_nav_id = Dict(get_prop(g_nav, i, :osm_id) => i for i in vertices(g_nav))
    osm_ids = collect(keys(osm_id_to_nav_id))

    rot_dir = 0
    @showprogress 1 "rebuilding topology" for start_node_id in vertices(g_nav)
        # get ways this node is part of
        start_osm_id = get_prop(g_nav, start_node_id, :osm_id)
        ways = [g.ways[way_id] for way_id in g.node_to_way[start_osm_id]]
        for way in ways
            # decompose way and filter to only include the ones in which the start node is contained
            simple_ways = filter(simple_way -> start_osm_id ∈ simple_way.nodes, decompose_way_to_primitives(way))
            for simple_way in simple_ways
                # define possible directions in which we are allowed to step through the way
                if simple_way.tags["oneway"]
                    step_directions = simple_way.tags["reverseway"] ? [-1] : [1]
                else
                    step_directions = [-1, 1]
                end

                all_nodes = simple_way.nodes
                topological_nodes = [node for node in all_nodes if node in osm_ids]

                for step in step_directions
                    rot_dir += get_rotational_direction(simple_way, g.nodes, step)

                    nodelist_start_destination = get_node_list(simple_way, start_osm_id, topological_nodes, step)
                    nodelist_start_destination === nothing && continue
                    linestring = geolinestring(g.nodes, nodelist_start_destination)

                    # project local to get length in meters
                    p = ArchGDAL.pointalongline(linestring, 0.5 * ArchGDAL.geomlength(linestring))
                    project_local!([linestring], ArchGDAL.getx(p, 0), ArchGDAL.gety(p, 0))
                    projected_length = ArchGDAL.geomlength(linestring)
                    project_back!([linestring])

                    data = Dict(
                        :osm_id => simple_way.id,
                        :tags => simple_way.tags,
                        :edgegeom => linestring,
                        :edgegeom_base => ArchGDAL.clone(linestring),
                        :full_length => projected_length,
                        :parsing_direction => step,
                        :helper => false
                    )
                    add_edge_with_data!(g_nav, start_node_id, osm_id_to_nav_id[nodelist_start_destination[end]]; data=data)
                end
            end
        end
    end

    rot_dir == 0 && @warn "not rotational direction could be found. choosing right hand side driving."
    if rot_dir >= 0
        @info "right hand side driving selected"
        rot_dir = 1
    else
        @info "left hand side driving selected"
        rot_dir = -1
    end

    set_prop!(g_nav, :crs, OSM_ref[])
    set_prop!(g_nav, :offset_dir, rot_dir)
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