trans(col, val::T) where {T<:ArchGDAL.IGeometry} = ArchGDAL.toWKT(val)
trans(col, val::T) where {T<:ArchGDAL.ISpatialRef} = ArchGDAL.toWKT(val)
trans(col, val) = val

"""
    export_graph_to_csv(path, graph; remove_internal_data = false)

saves the shadow graph to a selection of csv files:
- `"path"_nodes.csv`
- `"path"_edges.csv`
- `"path"_graph.csv` (contains graph properties)

# arguments
- `path`: path to the target directory. The different specifiers are appended to the filename given in this path.
- `graph`: shadow graph to save
- `remove_internal_data`: whether to remove internal data used for future calculations. (set this to true, if you do not need to be able to reimport the graph into `ShadowGraphs.jl` and want just the relevant "exposed" data)

# returns
saves multiple files to disk.
"""
function export_graph_to_csv(path, graph; remove_internal_data = false)
    if contains(path, '/')
        lastslash = findlast(==('/'), path)
        file = path[lastslash+1:end]
        dir = path[1:lastslash]
    else
        file = path
        dir = ""
    end
    if contains(file, '.')
        filename = file[1:findlast(==('.'), file)-1]
    else
        filename = file
    end
    node_df = DataFrame()
    for vertex in vertices(graph)
        vprop = props(graph, vertex)
        vprop[:vertex_id] = vertex
        push!(node_df, props(graph, vertex); cols=:union)
    end
    if remove_internal_data
        cols_to_remove = ["pointgeom"]
        cols_exist = names(node_df)
        select!(node_df, Not([i for i in cols_to_remove if i in cols_exist]))
    end
    
    node_file = dir * filename * "_nodes.csv"
    CSV.write(node_file, node_df; transform=trans)
    

    edge_df = DataFrame()
    for edge in edges(graph)
        eprop = props(graph, edge)
        eprop[:src_id] = src(edge)
        eprop[:dst_id] = dst(edge)
        push!(edge_df, eprop; cols=:union)
    end
    if remove_internal_data
        cols_to_remove = ["tags", "shadowpartgeom", "shadowed_part_length", "parsing_direction", "geomlength"]
        cols_exist = names(edge_df)
        select!(edge_df, Not([i for i in cols_to_remove if i in cols_exist]))
    end

    edge_file = dir * filename * "_edges.csv"
    CSV.write(edge_file, edge_df; transform=trans)


    graph_df = DataFrame()
    push!(graph_df, props(graph); cols=:union)

    graph_file = dir * filename * "_graph.csv"
    CSV.write(graph_file, graph_df; transform=trans)
end