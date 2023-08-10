trans(col, val::T) where {T<:ArchGDAL.IGeometry} = ArchGDAL.toWKT(val)
trans(col, val::T) where {T<:ArchGDAL.ISpatialRef} = ArchGDAL.toWKT(val)
trans(col, val) = val
DataFrames.tryparse(::Type{T}, string::AbstractString) where {T<:AbstractDict} = string |> Meta.parse |> eval

export_props(props, selector::AbstractVector) = filter(p -> first(p) in selector, props)
export_props(props, ::All) = props
export_props(props, selector::Not{Vector{Symbol}}) = filter(p -> !(first(p) in selector.skip), props)

"""
    export_shadow_graph_to_csv(path, graph; edge_props=All(), vertex_props=All(), graph_props=All())

saves the shadow graph to a selection of csv files:
- `"path"_nodes.csv`
- `"path"_edges.csv`
- `"path"_graph.csv` (contains graph properties)
All `ArchGDAL` geometries are converted to WellKnownText.

# arguments
- `path`: path to the target directory. The different specifiers are appended to the filename given in this path.
- `graph::MetaDiGraph`: shadow graph to save.

# keyword arguments
- `edge_props`
- `vertex_props`
- `graph_props`

are used to select which of the `props` on each edge, vertex and graph should be exported. Each argument takes either:
- `DataFrames.All()`: stores every property present. (inserts `missing` for all other properties.)
- `DataFrames.Not([...])`: stores every porperty except for the property names passed as a vector to `Not`. (example: `Not([:sg_helper, :sg_geometry_base])`)
- `[...]`: only exports the properties with names in the vector. (example: `[:sg_lon, :sg_lat, :sg_helper]`)

# returns
saves multiple files to disk.
"""
function export_shadow_graph_to_csv(path, graph; edge_props=All(), vertex_props=All(), graph_props=All())
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
        push!(node_df, export_props(vprop, vertex_props); cols=:union)
    end

    node_file = dir * filename * "_nodes.csv"
    CSV.write(node_file, node_df; transform=trans)

    edge_df = DataFrame()
    for edge in edges(graph)
        eprop = props(graph, edge)
        @assert !(:src_id in keys(eprop)) "the key :src_id on edge $edge is reserved for export."
        @assert !(:dst_id in keys(eprop)) "the key :dst_id on edge $edge is reserved for export."

        eprop = export_props(eprop, edge_props)
        push!(edge_df, eprop; cols=:union)
    end
    edge_df.src_id = src.(edges(graph))
    edge_df.dst_id = dst.(edges(graph))

    edge_file = dir * filename * "_edges.csv"
    CSV.write(edge_file, edge_df; transform=trans)

    graph_df = DataFrame()
    push!(graph_df, export_props(props(graph), graph_props); cols=:union)

    @assert !(has_prop(graph, :defaultweight)) "the key :defaultweight on the graph is reserved for export."
    @assert !(has_prop(graph, :weightfield)) "the key :weightfield on the graph is reserved for export."

    graph_df.defaultweight = [defaultweight(graph)]
    graph_df.weightfield = [weightfield(graph)]

    graph_file = dir * filename * "_graph.csv"
    CSV.write(graph_file, graph_df; transform=trans)
end

"""
    import_shadow_graph_from_csv(path)

imports csvs saved via `export_shadow_graph_to_csv`. `path` points to the main name of the files (without suffixes).
(Just plug in the same thing you plugged in to save the graph).

# returns
- `edge_df, vertex_df, graph_df`: the loaded csv files as `DataFrames` to be further processed into whatever you need them to be.
"""
function import_shadow_graph_from_csv(path)
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
    edge_df = CSV.read(edge_file, DataFrame)#; types=Dict(:tags => Dict{String,Any}))
    graph_df = CSV.read(graph_file, DataFrame)

    g = MetaDiGraph()
    defaultweight!(g, graph_df.defaultweight[1])
    weightfield!(g, Symbol(graph_df.weightfield[1]))

    return edge_df, node_df, graph_df

    # this code is kept around as a reference for possible future changes to the loading mechanism...
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
