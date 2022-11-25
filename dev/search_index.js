var documenterSearchIndex = {"docs":
[{"location":"Persistence/#Persistence","page":"IO","title":"Persistence","text":"","category":"section"},{"location":"Persistence/#Introduction","page":"IO","title":"Introduction","text":"","category":"section"},{"location":"Persistence/","page":"IO","title":"IO","text":"Here we collect functions responsible for saving and loading ShadowGraphs to multiple CSV files. Currently, only saving with two different levels of verbosity is supported.","category":"page"},{"location":"Persistence/#API","page":"IO","title":"API","text":"","category":"section"},{"location":"Persistence/","page":"IO","title":"IO","text":"Pages = [\"Persistence.md\"]","category":"page"},{"location":"Persistence/","page":"IO","title":"IO","text":"Modules = [ShadowGraphs]\nPages = [\"Persistence.jl\"]","category":"page"},{"location":"Persistence/#ShadowGraphs.export_graph_to_csv-Tuple{Any, Any}","page":"IO","title":"ShadowGraphs.export_graph_to_csv","text":"export_graph_to_csv(path, graph; remove_internal_data = false)\n\nsaves the shadow graph to a selection of csv files:\n\n\"path\"_nodes.csv\n\"path\"_edges.csv\n\"path\"_graph.csv (contains graph properties)\n\narguments\n\npath: path to the target directory. The different specifiers are appended to the filename given in this path.\ngraph: shadow graph to save\nremove_internal_data: whether to remove internal data used for future calculations. (set this to true, if you do not need to be able to reimport the graph into ShadowGraphs.jl and want just the relevant \"exposed\" data)\n\nreturns\n\nsaves multiple files to disk.\n\n\n\n\n\n","category":"method"},{"location":"Plotting/#Plotting","page":"Plotting","title":"Plotting","text":"","category":"section"},{"location":"Plotting/#Introduction","page":"Plotting","title":"Introduction","text":"","category":"section"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"We extend the functionality of (Folium.jl)[https://github.com/SuperGrobi/Folium.jl] to be quickly able to visualise the shadowgraph in an interactive Leaflet.js map.","category":"page"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"As most alternative packages in julia are quiet slow with regards to the drawing of very large graphs, this is currently the only way of getting close to interactive maps.","category":"page"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"TODO:","category":"page"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"maybe vectorise the inputs to set values \"per edge\"/ \"per node\" (GraphRecipes.jl?)\nuse/find alternative options to plot static (publication) level networks","category":"page"},{"location":"Plotting/#API","page":"Plotting","title":"API","text":"","category":"section"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"Pages = [\"Plotting.md\"]","category":"page"},{"location":"Plotting/","page":"Plotting","title":"Plotting","text":"Modules = [ShadowGraphs]\nPages = [\"Plotting.jl\"]","category":"page"},{"location":"Plotting/#Folium.draw!-Union{Tuple{T}, Tuple{Folium.FoliumMap, T, Symbol}} where T<:MetaGraphs.AbstractMetaGraph","page":"Plotting","title":"Folium.draw!","text":"draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}\n\ndraws the given data series properies of the graph into a Folium.jl map.\n\narguments\n\nfig::FoliumMap: map to draw in\ng: shadow graph carying the data\nseries_type: type of data to draw from the graph. Pick from: :vertices, :edges, :edgegeom, :shadowgeom.\ndrawarrows: if there should be a circle drawn 80% along the edgegeom. (only applies when `seriestypeis:edgegeom`)\nkwargs: keywords passed to folium for every series_type. (see the python docs and the leaflet docs for a full list of all options.) \n\nEvery series_type has a few sensible defaults set, most importantly the default tooltips and popups, which, by default show some interesting data about the vertices and edges, respectively. Currently, the kwargs are set for every element, there is (currently) no way to set parameters with, for example a vector, to get a element by element arguments.\n\nreturns\n\nfig::FoliumMap (passthrough of argument)\n\n\n\n\n\n","category":"method"},{"location":"Plotting/#Folium.draw-Union{Tuple{T}, Tuple{T, Symbol}} where T<:MetaGraphs.AbstractMetaGraph","page":"Plotting","title":"Folium.draw","text":"draw(g::T, series_type::Symbol; figure_params=Dict(), kwargs...) where {T<:AbstractMetaGraph}\n\nsame as draw!, but creates a new FoliumMap first.\n\nargumnents\n\nsame as draw! plus:\nfigure_params: dictionary with arguments which are getting passed to the FoliumMap constructor (see the python docs and the leaflet docs for a full list of all options.)\n\nreturns\n\nthe newly created figure\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#Building-Graphs","page":"Graph creation","title":"Building Graphs","text":"","category":"section"},{"location":"BuildGraph/#Introduction","page":"Graph creation","title":"Introduction","text":"","category":"section"},{"location":"BuildGraph/","page":"Graph creation","title":"Graph creation","text":"We use LightOSM.jl as a basis to handle all the downloading, saving and importing of OSM data. Therefore, we expose very functions very similar to the ones in LightOSM.jl.","category":"page"},{"location":"BuildGraph/","page":"Graph creation","title":"Graph creation","text":"Then, the resulting LightOSM.OSMGraph instance is parsed into a MetaDiGraph, which is preserves the topology of the original street network, while reducing the number of nodes as much as possible. The geometry and various other parameters are attached to the props of every edge and vertex.","category":"page"},{"location":"BuildGraph/","page":"Graph creation","title":"Graph creation","text":"Even though we only expose a few functions for ease of use, we show all functions here, since it is very important to get an idea of what exactly this code is doing to your graph, before you start using it in any scientific capacity.","category":"page"},{"location":"BuildGraph/#API","page":"Graph creation","title":"API","text":"","category":"section"},{"location":"BuildGraph/","page":"Graph creation","title":"Graph creation","text":"Pages = [\"BuildGraph.md\"]","category":"page"},{"location":"BuildGraph/","page":"Graph creation","title":"Graph creation","text":"Modules = [ShadowGraphs]\nPages = [\"BuildGraph.jl\"]","category":"page"},{"location":"BuildGraph/#ShadowGraphs.add_edge_with_data!-Tuple{Any, Any, Any}","page":"Graph creation","title":"ShadowGraphs.add_edge_with_data!","text":"add_edge_with_data!(g, s, d; data=Dict())\n\nadds new edge from s to d to g::MetaDiGraph, and populates it with the props given in data.\n\ndata is expected to have at least a key :edgegeom, containing the geometry of the street between s and d as an ArchGDAL linestring in the WSG84 system. (Use apply_wsg_84!)\n\nSpecial care is given to self and multi edges:\n\nself edges: if s==d, actually two new vertices are added at 10% and 60% along the :edgegeom, with props of :lat, :lon, pointgeom and :helper=true set acordingly.\n\nThese new vertices (h1 and h2) are then connected to form a loop like: s --he1--> h1 --real_edge--> h2 --he2--> d, where he1 and he2 are helper edges with only one prop of :helper=true. real_edge is carrying all the props defined in data\n\nmulti edges: if Edge(s,d) ∈ Edges(g), we add one new helper vertex at 50% along the :edgegeom with props of :lat, :lon, pointgeom and :helper=true.\n\nWe connect to the graph like this: s --he--> h --real_edge--> d, where he is a helper edge with only one prop, :helper=true. real_edge carries all the props specified in data\n\nThis process is nessecary to preserve the street network topology, since MetaDiGraphs do not support multi edges (and therefore also no multi self edges).\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.add_this_node-Tuple{Any, Any}","page":"Graph creation","title":"ShadowGraphs.add_this_node","text":"add_this_node(g, osm_id)\n\nchecks if the node with osm_id in graph g should be added to the shadow graph. Churrently, we add a node if one of the following is true:\n\nif the number of ways the node is part of is larger than 1\nif the node is the end of a street, that is, if he has only one neighbour in g\nif the node occurs more than once in the way it is part of, excluding the end point, if the way is circular\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.countall-Tuple{Any}","page":"Graph creation","title":"ShadowGraphs.countall","text":"countall(numbers)\n\ncounts how often every number appears in numbers. Returns dict with number=>count\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.decompose_way_to_primitives-Tuple{LightOSM.Way}","page":"Graph creation","title":"ShadowGraphs.decompose_way_to_primitives","text":"decompose_way_to_primitives(way::Way)\n\nDecomposed a way with possible self-intersections/loops into multiple ways which are guaranteed to be either\n\nnon-intersecting lines, where every node in the way is unique, or\ncircular ways, where only the first and last node in the way are not unique.\n\nexample\n\na simple way with nodes [10,20,30,40,50,30] (which looks like a triangle on a stick, not the repeated 30) will be decomposed into two ways, with the nodes [10,20,30] and [30,40,50,30].\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.geolinestring-Tuple{Any, Any}","page":"Graph creation","title":"ShadowGraphs.geolinestring","text":"geolinestring(nodes, node_id_list)\n\ncreates an ArchGDAL linestring from a dictionary mapping osm node ids to LightOSM.Node and a list of osm node ids, representing the nodes of the linestring in order.\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.get_node_list-NTuple{4, Any}","page":"Graph creation","title":"ShadowGraphs.get_node_list","text":"get_node_list(simple_way, start_osm_id, topological_nodes, direction)\n\ntries to get list of osm ids in simple_way between the startosmid and the next topologically relevant node in direction of direction. Returns either Int[] or nothing if there is no relevant node in direction of direction.\n\nUsed only on simplified ways.\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.get_rotational_direction-Tuple{LightOSM.Way, Any, Any}","page":"Graph creation","title":"ShadowGraphs.get_rotational_direction","text":"get_rotational_direction(way::Way, nodes, direction)\n\ncalculates the direction of rotation of the way if walked through in the direction of direction (either 1 or -1). Since the node locations are stored seperately, you have to pass in a dict node_id=>LightOSM.Node seperately. Used only on simplified ways.\n\nReturns\n\n1 if the rotation is righthanded\n-1 if the rotation is lefthanded\n0 if the way is not closed\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.is_circular_way-Tuple{LightOSM.Way}","page":"Graph creation","title":"ShadowGraphs.is_circular_way","text":"is_circular_way(way::Way)\n\nchecks if a LightOSM.Way way starts at the same node it ends.\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.is_end_node-Tuple{Any, Any}","page":"Graph creation","title":"ShadowGraphs.is_end_node","text":"is_end_node(g, index)\n\nchecks if node index in graph g represents the end of a street (that is, has as most one neighbour).\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.parse_lanes-Tuple{AbstractDict, Any}","page":"Graph creation","title":"ShadowGraphs.parse_lanes","text":"parse_lanes(tags::AbstractDict, tagname)\n\nparses the value of the key tagname in tags, assuming it to be a numerical value describing a certain number of lanes. Returns the parsed number of lanes if the tag exists or missing if not.\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.parse_raw_ways-Tuple{Any, Any}","page":"Graph creation","title":"ShadowGraphs.parse_raw_ways","text":"parse_raw_ways(raw_ways, network_type)\n\nparses a list of dicts describing OSM Ways into LightOSM.Way instances. This function is a slightly modified version of the one used in LightOSM (parse_osm_network_dict), to be able to use our own, non-dafault value assuming parsers for the labels.\n\nreturns\n\na dictionary mapping osm_id to LightOSM.Way\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.shadow_graph_from_download-Tuple{Symbol}","page":"Graph creation","title":"ShadowGraphs.shadow_graph_from_download","text":"function shadow_graph_from_download(download_method::Symbol;\n                                    network_type::Symbol=:drive,\n                                    metadata::Bool=false,\n                                    download_format::Symbol=:json,\n                                    save_to_file_location::Union{String,Nothing}=nothing,\n                                    download_kwargs...)\n\ndownloads and builds the shadow graph from OSM.\n\narguments\n\ndownload_method::Symbol: Download method, choose from :place_name, :bbox or :point.\nnetwork_type::Symbol=:drive: Network type filter, pick from :drive, :drive_service, :walk, :bike, :all, :all_private, :none, :rail\nmetadata::Bool=false: Set true to return metadata.\ndownload_format::Symbol=:json: Download format, either :osm, :xml or json.\nsave_to_file_location::Union{String,Nothing}=nothing: Specify a file location to save downloaded data to disk.\n\nRequired Kwargs for each Download Method\n\ndownload_method=:place_name\n\nplace_name::String: Any place name string used as a search argument to the Nominatim API.\n\ndownload_method=:bbox\n\nminlat::AbstractFloat: Bottom left bounding box latitude coordinate.\nminlon::AbstractFloat: Bottom left bounding box longitude coordinate.\nmaxlat::AbstractFloat: Top right bounding box latitude coordinate.\nmaxlon::AbstractFloat: Top right bounding box longitude coordinate.\n\ndownload_method=:point\n\npoint::GeoLocation: Centroid point to draw the bounding box around.\nradius::Number: Distance (km) from centroid point to each bounding box corner.\n\ndownload_method=:polygon\n\npolygon::AbstractVector: Vector of longitude-latitude pairs.\n\nNetwork Types\n\n:drive: Motorways excluding private and service ways.\n:drive_service: Motorways including private and service ways.\n:walk: Walkways only.\n:bike: Cycleways only.\n:all: All motorways, walkways and cycleways excluding private ways.\n:all_private: All motorways, walkways and cycleways including private ways.\n:none: No network filters.\n:rail: Railways excluding proposed and platform.\n\nreturns\n\nMetaDiGraph with topologically relevant nodes and edges and relevant data attached to every node and edge.\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.shadow_graph_from_file-Tuple{String}","page":"Graph creation","title":"ShadowGraphs.shadow_graph_from_file","text":"shadow_graph_from_file(file_path::String; network_type::Symbol=:drive)\n\nbuilds the shadow graph from a file containing OSM data. The file could have been downloaded with either shadow_graph_from_download or download_osm_network.\n\narguments\n\nfile_path: path to file. either .osm, .xml or .json\nnetwork_type: type of network stored in file. Options are the same as in LightOSM: \n\n:drive, :drive_service, :walk, :bike, :all, :all_private, :none, :rail\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.shadow_graph_from_light_osm_graph-Tuple{Any}","page":"Graph creation","title":"ShadowGraphs.shadow_graph_from_light_osm_graph","text":"shadow_graph_from_light_osm_graph(g)\n\ntransforms a LightOSM.OSMGraph into a MetaDiGraph, containing only the topologically relevant nodes and edges. Attached to every edge and node comes a lot of data, describing this specific edge or node:\n\nnodes\n\nin the case of helper nodes:\n\n:lat\n:lon\npointgeom\n:helper=true\n\nin the case of non helper nodes:\n\n:osm_id\n:lat\n:lon\npointgeom\n:helper=false\n\nedges\n\nin the case of helper edges:\n\n:helper=true\n\nin the case of non helper edges:\n\n:osm_id\n:tags (tags of the original osm way, with parsed width, lanes, lanes:forward, lanes:backward and lanes:both_ways, oneway and reverseway keys)\n:edgegeom (ArchGDAL linestring with the geometry of the edge)\n:geomlength=0\n:parsing_direction (direction in which we stepped through the original way nodes to get the linestring)\n:helper=false \n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.shadow_graph_from_object-Tuple{Union{LightXML.XMLDocument, Dict}}","page":"Graph creation","title":"ShadowGraphs.shadow_graph_from_object","text":"shadow_graph_from_object(osm_data_object::Union{XMLDocument,Dict}; network_type::Symbol=:drive)\n\nbuilds the shadow graph from an object holding the raw OSM data. This function is using the graph_from_object function from LightOSM to first build a LightOSM.OSMGraph object which then gets augmented with the custom parsed ways, before it gets handed over to the shadow_graph_from_light_osm_graph function.\n\narguments\n\nosmdataobject\nnetworktype: type of network stored in osmdata_object. Options are the same as in LightOSM: \n\n:drive, :drive_service, :walk, :bike, :all, :all_private, :none, :rail\n\n\n\n\n\n","category":"method"},{"location":"BuildGraph/#ShadowGraphs.width-Tuple{Any}","page":"Graph creation","title":"ShadowGraphs.width","text":"width(tags)\n\nless opinionated version of the basic parsing LightOSM does, to parse the width tag of an osm way. Returns the parsed width if the tag exists or missing if not.If Values are negative, we take the absolute value.\n\n\n\n\n\n","category":"method"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = ShadowGraphs","category":"page"},{"location":"#ShadowGraphs","page":"Home","title":"ShadowGraphs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for ShadowGraphs.","category":"page"}]
}
