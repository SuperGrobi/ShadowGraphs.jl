function trans(col, val::T) where {T<:ArchGDAL.IGeometry}
    return ArchGDAL.toWKT(val)
end
function trans(col, val)
    return val
end

function save_graph_to_csv(path, graph; remove_internal_data = false)
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
        cols_to_remove = ["pointgeom", "nonexitsten_col"]
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
        cols_to_remove = ["tags", "parsing_direction"]
        cols_exist = names(edge_df)
        select!(edge_df, Not([i for i in cols_to_remove if i in cols_exist]))
    end

    edge_file = dir * filename * "_edges.csv"
    CSV.write(edge_file, edge_df; transform=trans)
end