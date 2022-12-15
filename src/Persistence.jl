trans(col, val::T) where {T<:ArchGDAL.IGeometry} = ArchGDAL.toWKT(val)
trans(col, val::T) where {T<:ArchGDAL.ISpatialRef} = ArchGDAL.toWKT(val)
trans(col, val) = val
DataFrames.tryparse(::Type{T}, string::AbstractString) where {T<:AbstractDict} = string |> Meta.parse |> eval

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

"""

    import_graph_from_csv(path)

imports graph saved via export_graph_to_csv. `path` points to the main name of the files (without suffixes).
(Just plug in the same thing you plugged in to save the graph).
"""
function import_graph_from_csv(path)
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

    node_file = dir * filename * "_nodes.csv"
    edge_file = dir * filename * "_edges.csv"
    graph_file = dir * filename * "_graph.csv"

    node_df = CSV.read(node_file, DataFrame)
    edge_df = CSV.read(edge_file, DataFrame; types=Dict(:tags=>Dict{String, Any}))
    graph_df = CSV.read(graph_file, DataFrame)

    g = MetaDiGraph()

    for node in eachrow(node_df)
        pointgeom = ArchGDAL.fromWKT(node.pointgeom)
        apply_wsg_84!(pointgeom)
        data = Dict(Symbol.(names(node)) .=> values(node))
        delete!(data, :vertex_id)
        data[:pointgeom] = pointgeom
        add_vertex!(g, data)
    end
    for edge in eachrow(edge_df)
        data = Dict(Symbol.(names(edge)) .=> values(edge))
        for key in keys(data)
            try
                data[key] = ArchGDAL.fromWKT(data[key])
                apply_wsg_84!(data[key])
            catch
            end
        end
        src_id = pop!(data, :src_id)
        dst_id = pop!(data, :dst_id)
        add_edge!(g, src_id, dst_id, data)
    end

    for graph in eachrow(graph_df)
        data = Dict(Symbol.(names(graph)) .=> values(graph))
        for prop in data
            set_prop!(g, first(prop), last(prop))
        end
        set_prop!(g, :crs, OSM_ref[])
    end

    return g

    return edge_df
end
