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

function point_on_radius(x, y, r)
    ϕ = rand() * 2π
    dx = r * cos.([ϕ, ϕ+π/3])
    dy = r * sin.([ϕ, ϕ+π/3])
    return x.+dx, y.+dy
end

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

function add_node_with_data!(g, n; data=Dict())
    add_vertex!(g)
    for (key,value) in data
        set_prop!(g, n, key, value)
    end
end


function add_edge_with_data!(g, s, d; data=Dict())
    if s == d  # if we are about to add a self-loop
        #@warn "trying to add self loop for node $(get_prop(g, s, :osm_id)) ($s)"
        lat_start = get_prop(g, s, :lat)
        lon_start = get_prop(g, s, :lon)
        lons, lats= point_on_radius(lon_start, lat_start, 0.0003)
        # TODO: add archGDAL point to props
        add_vertex!(g, Dict(:osm_id=>0, :lat=>lats[1], :lon=>lons[1], :helper=>true, :end=>false))
        id_1 =nv(g)
        add_edge!(g, s, id_1, :helper, true)
        add_vertex!(g, Dict(:osm_id=>0, :lat=>lats[2], :lon=>lons[2], :helper=>true, :end=>false))
        id_2 = nv(g)
        add_edge!(g, id_2, d, :helper, true)
        add_edge_with_data!(g, id_1, id_2; data=data)
    else
        if has_edge(g, s, d)
            #@warn "trying to add multi-edge from node $(get_prop(g, s, :osm_id)) ($s) to $(get_prop(g, d, :osm_id)) ($d)"
            # all of this is bad...
            lon_new, lat_new = offset_point_between(g, s, d)
            add_vertex!(g, Dict(:osm_id=>0, :lat=>lat_new, :lon=>lon_new, :helper=>true, :end=>false))
            add_edge!(g, s, nv(g), :helper, true)
            add_edge_with_data!(g, nv(g), d; data=data)
        else
            add_edge!(g, s, d)
            for (key, value) in data
                set_prop!(g, s, d, key, value)
            end
        end
    end
end

is_circular_way(way::Way) = way.nodes[1] == way.nodes[end]

function get_neighbor_indices(way::Way, start_id_index, nodes_in_nav_graph)
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

function is_lolipop_node(g, osm_id)
    way_id = first(g.node_to_way[osm_id])
    way = g.ways[way_id]
    nodes = way.nodes
    ocurrences = count(x->x==osm_id, nodes)
    ocurrences > 2 && @warn "the node $osm_id is contained $ocurrences in a way. better check that out..."
    return ocurrences == 2 && !is_circular_way(way)
end

function get_node_list(way, start_pos, dest_osm_id, direction)
    nodes = way.nodes
    string_nodes = [nodes[start_pos]]
    current_pos = mod(start_pos + direction - 1, length(way.nodes)) + 1
    while nodes[current_pos] != dest_osm_id
        # exclude duplicates where rings close
        if !(way.nodes[current_pos] in string_nodes)
            push!(string_nodes, way.nodes[current_pos])
        end
        current_pos = mod(current_pos + direction - 1, length(way.nodes)) + 1
    end
    push!(string_nodes, way.nodes[current_pos])
    return string_nodes
end

function nodelist_between(way, start_osm_id, dest_osm_id, direction)
    # find start and end index in way.nodes and take everything in between
    start_pos = findall(x->x==start_osm_id, way.nodes)
     
    if length(start_pos) == 1
        start_pos = first(start_pos)
        string_nodes = get_node_list(way, start_pos, dest_osm_id, direction)
    else
        length(start_pos) > 2 && @warn "the start node $start_osm_id apears $(length(start_pos)) times in the way."
        # this assumes, that nodes occure at most twice in every way
        if start_osm_id == dest_osm_id
            string_nodes = way.nodes[start_pos[1]:start_pos[end]]
        else  # this is for everything else, I assume that if I start from both nodes in the right direction, the shorter path will be the one I want...
            # the longer I think about it, this might actually be generally correct for all cases in this clause, due to the one dimensionality of ways.
            node_lists = [get_node_list(way, start, dest_osm_id, direction) for start in start_pos]
            string_nodes = node_lists[findmin(length, node_lists)[2]]
        end
    end
    return string_nodes
end

function geolinestring(nodes, node_id_list)
    nodelist = [nodes[id] for id in node_id_list]
    location_tuples = [(node.location.lon, node.location.lat) for node in nodelist]
    linestring = ArchGDAL.createlinestring(location_tuples)
    apply_wsg_84!(linestring)
    return linestring
end

"""
This is the final function getting called on shadow graph creation.
It takes a fully formed LightOSM.OSMGraph instance and transforms
it to the graph we want to have. (whatever that may be...)
"""
function shadow_graph_from_light_osm_graph(g) 
    # make the streets nodes are a part contain only unique elements
    g.node_to_way = Dict(key => collect(Set(value)) for (key, value) in g.node_to_way)
    # build clean graph containing only nodes for topologically relevant nodes
    g_nav = MetaDiGraph()

    # add only those nodes, which are part of two or more ways or ends of streets
    current_new_index = 1
    for (osm_id, ways) in g.node_to_way
        index = g.node_to_index[osm_id]
        if length(ways) > 1 || is_end_node(g.graph, index) || is_lolipop_node(g, osm_id)
            lat_point = g.nodes[osm_id].location.lat
            lon_point = g.nodes[osm_id].location.lon
            point = ArchGDAL.createpoint(lon_point, lat_point)
            apply_wsg_84!(point)
            data = Dict(
                :(osm_id) => osm_id,
                :lat => lat_point,
                :lon => lon_point,
                :end => is_end_node(g.graph, index),
                :geopoint=>point
            )
            add_node_with_data!(g_nav, current_new_index; data=data)
            current_new_index += 1
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

            # cut of duplicate node, if the way starts and ends here.
            if nodes_in_nav_graph[1] == nodes_in_nav_graph[end]
                nodes_in_nav_graph = nodes_in_nav_graph[1:end-1]
            end

            start_id_indices = findall(x->x==start_osm_id, nodes_in_nav_graph)
            if length(start_id_indices)!=1 && !is_lolipop_node(g, start_osm_id)
                @warn "the start node $start_osm_id is $(length(start_id_indices)) times in the shortened way."
            end

            for start_id_index in start_id_indices
                neighbor_indices, step_directions = get_neighbor_indices(way, start_id_index, nodes_in_nav_graph)
                for (next_osm_id, step_direction) in zip(neighbor_indices, step_directions)
                    next_nav_id = osm_id_to_nav_id[next_osm_id]
                    node_id_list = nodelist_between(way, start_osm_id, next_osm_id, step_direction)
                    linestring = geolinestring(g.nodes, node_id_list)
                    data = Dict(
                        :(osm_id) => way.id,
                        :geolinestring => linestring,
                        :geomlength => 0
                    )
                    add_edge_with_data!(g_nav, start_node_id, next_nav_id; data=data)
                end
            end
        end
    end

    # build ArchGDAL linestring from high density graph and attach it to every edge
    
    return g, g_nav
end

function shadow_graph_from_object(osm_data_object::Union{XMLDocument,Dict};
    network_type::Symbol=:drive,
    weight_type::Symbol=:time,  # this may become obsolete
    graph_type::Symbol=:static,  # this also...
    precompute_dijkstra_states::Bool=false, # this also...
    largest_connected_component::Bool=true  # this also...
    )
    g = graph_from_object(osm_data_object;
        network_type=network_type,
        weight_type=weight_type,
        graph_type=graph_type,
        precompute_dijkstra_states=precompute_dijkstra_states,
        largest_connected_component=largest_connected_component
        )
    return shadow_graph_from_light_osm_graph(g)
end

function shadow_graph_from_file(file_path::String;
    network_type::Symbol=:drive,
    weight_type::Symbol=:time,  # this might become obsolete
    graph_type::Symbol=:static,  # this also...
    precompute_dijkstra_states::Bool=false,  # this also... 
    largest_connected_component::Bool=true  # this also...
    )
    g = graph_from_file(file_path;
    network_type=network_type,
    weight_type=weight_type,  # this might become obsolete
    graph_type=graph_type,  # this also...
    precompute_dijkstra_states=precompute_dijkstra_states,  # this also... 
    largest_connected_component=largest_connected_component  # this also...
    )
    return shadow_graph_from_light_osm_graph(g)
end

function shadow_graph_from_download(download_method::Symbol;
        network_type::Symbol=:drive,
        metadata::Bool=false,
        download_format::Symbol=:json,
        save_to_file_location::Union{String,Nothing}=nothing,
        weight_type::Symbol=:time,  # this might become obsolete
        graph_type::Symbol=:static,  # this also...
        precompute_dijkstra_states::Bool=false,  # this also...
        largest_connected_component::Bool=true,  # this also...
        download_kwargs...)
    g = graph_from_download(download_method;
        network_type=network_type,
        metadata=metadata,
        download_format=download_format,
        save_to_file_location=save_to_file_location,
        weight_type=weight_type,  # this might become obsolete
        graph_type=graph_type,  # this also...
        precompute_dijkstra_states=precompute_dijkstra_states,  # this also...
        largest_connected_component=largest_connected_component,  # this also...
        download_kwargs...)
    return shadow_graph_from_light_osm_graph(g)
end
    
