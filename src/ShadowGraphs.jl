module ShadowGraphs
using CoolWalksUtils
using LightOSM
using LightXML
using Graphs
using MetaGraphs
using Folium
using ProgressMeter
using ArchGDAL
using Statistics
using DataFrames
using StatsBase
using CSV

const EdgeGeomType = Union{ArchGDAL.IGeometry{ArchGDAL.wkbLineString},ArchGDAL.IGeometry{ArchGDAL.wkbMultiLineString}}
include("Projection.jl")

export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("BuildGraph.jl")

include("Plotting.jl")

export export_graph_to_csv, import_graph_from_csv
include("Persistence.jl")

"""

    CoolWalksUtils.build_rtree(g::AbstractMetaGraph)

builds `SpatialIndexing.RTree{Float64, 2}` from an `AbstractMetaGraph` containing vertices with at least an `:pointgeom` prop and edges with a `:edgegeom` prop
(edges without this prop are getting skipped, but do not throw an error.)

The `id` of each entry is of type `Edge` and represents the edge the values are derived from. If the entry is a vertex, the `id` will be an `Edge(v,v)`.
(See also the `val.type` entry on how to distiguish between edges and nodes.)

The value of an entry in the RTree is a named tuple with: `(prep=prepared_geometry, type=graph_geom_type, props=properties_of_type)`. `prep` is the prepared geometry,
derived from `props[:pointgeom]` or `props[:edgegeom]` and can be used in a few `ArchGDAL` functions to get higher performance, for example in intersection testing, 
because relevant values get precomputed and cashed in the prepared geometry, rather than precomputed on every test.

The `type` entry is either `:vertex` or `:edge`, to help distinguish between entries for edges and vertices.

The `props` entry contains the Dictionary returned by `props(g, i)` where i is either a vertex or an edge. This gives access to all relevant properties of the graph.
"""
function CoolWalksUtils.build_rtree(g::AbstractMetaGraph)
    rt = RTree{Float64,2}(Edge, NamedTuple{(:prep, :type, :props),Tuple{ArchGDAL.IPreparedGeometry,Symbol,Dict{Symbol,Any}}})
    vs = nv(g)
    for v in vertices(g)
        geom = get_prop(g, v, :pointgeom)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, Edge(v, v), (prep=ArchGDAL.preparegeom(geom), type=:vertex, props=props(g, v)))
    end
    for e in edges(g)
        !has_prop(g, e, :edgegeom) && continue
        geom = get_prop(g, e, :edgegeom)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, e, (prep=ArchGDAL.preparegeom(geom), type=:edge, props=props(g, e)))
    end
    return rt
end

end  # module