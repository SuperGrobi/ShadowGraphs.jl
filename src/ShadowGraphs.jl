module ShadowGraphs
using CoolWalksUtils
using LightOSM
using LightXML
using Graphs
using MetaGraphs
using Folium

using ProgressMeter
using ProgressBars

using ArchGDAL
using Statistics
using DataFrames
using StatsBase
using SpatialIndexing
using GeoInterface
using CSV
using Extents
using TimeZones
using IterTools


# TODO: Rework Measures
# TODO: Rework Persistence
# TODO: Rework Projection
# TODO: Rework this file

const EdgeShadowGeomType = Union{ArchGDAL.IGeometry{ArchGDAL.wkbLineString},ArchGDAL.IGeometry{ArchGDAL.wkbMultiLineString}}
const EdgeStreetGeomType = ArchGDAL.IGeometry{ArchGDAL.wkbLineString}
const VertexGeomType = ArchGDAL.IGeometry{ArchGDAL.wkbPoint}

include("Projection.jl")

export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("BuildGraph.jl")

include("Plotting.jl")

export export_graph_to_csv, import_graph_from_csv
include("Persistence.jl")

export tag_edge_bearings!, single_bearing
include("Measures.jl")


"""
    check_shadow_graph_integrity(g; strict=false)

checks if all the properties needed to be a shadow graph are present in g. See the documentation for an overview.

If `strict=true`, we check if there are only the needed `props` present. Use this to test a non-mutated graph
(for example directly after construction, before adding shadows).
"""
function check_shadow_graph_integrity(g; strict=false)
    @info "integrity check..."
    @assert g isa MetaDiGraph "the graph is not a  MetaDiGraph."

    needed_node_props = [:sg_osm_id, :sg_lon, :sg_lat, :sg_geometry, :sg_helper]
    # check all vertices
    for v in vertices(g)
        for prop in needed_node_props
            @assert has_prop(g, v, prop) "vertex $v has no $prop prop."
        end
        @assert get_prop(g, v, :sg_geometry) isa VertexGeomType ":sg_geometry of vertex $v is not an ArchGDAL point."
        if strict
            @assert length(props(g, v)) == length(needed_node_props) "vertex $v has more props than required."
        end
    end

    needed_non_helper_edge_props = [
        :sg_osm_id,
        :sg_tags,
        :sg_street_geometry,
        :sg_geometry_base,
        :sg_street_length,
        :sg_parsing_direction]  # and :sg_helper (checked separately)
    # check all edges
    for e in edges(g)
        @assert has_prop(g, e, :sg_helper) "edge $e has no :sg_helper prop set."
        if !get_prop(g, e, :sg_helper)
            for prop in needed_non_helper_edge_props
                @assert has_prop(g, e, prop) "edge $e has no $prop prop."
            end
            if strict
                @assert length(props(g, e)) == length(needed_non_helper_edge_props) + 1 "edge $e has more props than required."
            end
            @assert get_prop(g, e, :sg_street_geometry) isa EdgeStreetGeomType ":sg_street_geometry of edge $e is not an ArchGDAL linestring."
            @assert get_prop(g, e, :sg_geometry_base) isa EdgeStreetGeomType ":sg_geometry_base of edge $e is not an ArchGDAL linestring."
        else
            if strict
                @assert length(props(g, e)) == 1 "helper edge $e has more props than required."
            end
        end
    end

    # check graph metadata
    needed_graph_props = [:sg_crs, :sg_offset_dir, :sg_observatory]
    for prop in needed_graph_props
        @assert has_prop(g, prop) "graph has no $prop prop."
    end
    @assert get_prop(g, :sg_observatory) isa ShadowObservatory ":sg_observatory is not a ShadowObservatory."
    if strict
        @assert length(props(g)) == length(needed_graph_props) "the graph has more props than required."
    end

    @assert weightfield(g) == :sg_street_length "the weightfield of the graph is not set to `:sg_street_length`"
    @assert defaultweight(g) == 0.0 "the defaultweight of the graph is not set to 0.0"

    @info "complete. All good!"
end


outedges(g, v) = Edge.(v, outneighbors(g, v))
inedges(g, v) = Edge.(inneighbors(g, v), v)
get_prop_default(g, e, p, default) = has_prop(g, e, p) ? get_prop(g, e, p) : default
export outedges, inedges, get_prop_default

"""

    CoolWalksUtils.build_rtree(g::AbstractMetaGraph)

builds `SpatialIndexing.RTree{Float64, 2}` from an `AbstractMetaGraph` containing vertices with at least an `:pointgeom` prop and edges with a `:edgegeom` prop
(edges without this prop are getting skipped, but do not throw an error.)

The `id` of each entry is of type `Edge` and represents the edge the values are derived from. If the entry is a vertex, the `id` will be an `Edge(v,v)`.
(See also the `val.type` entry on how to distiguish between edges and nodes.)

The value of an entry in the RTree is a named tuple with: `(orig=original_geometry, prep=prepared_geometry, type=graph_geom_type, props=properties_of_type)`.
where `orig` is the original geometry stored in `props[:pointgeom]` or `props[:edgegeom]`, and `prep` is the prepared geometry, derived from `orig`. The latter one
can be used in a few `ArchGDAL` functions to get higher performance, for example in intersection testing, because relevant values get precomputed and cashed in the
prepared geometry, rather than precomputed on every test. Note that only the first element in these tests can be a prepared geometry,
for example `ArchGDAL.intersects(normal_geom, prepared_geom)` is a highway to the segfault-zone, where `ArchGDAL.intersects(prepared_geom, normal_geom)` is fine and great.

The `type` entry is either `:vertex` or `:edge`, to help distinguish between entries for edges and vertices.

The `props` entry contains the Dictionary returned by `props(g, i)` where i is either a vertex or an edge. This gives access to all relevant properties of the graph.
"""
function CoolWalksUtils.build_rtree(g::AbstractMetaGraph)
    rt = RTree{Float64,2}(Edge, NamedTuple{(:orig, :prep, :type, :props),Tuple{ArchGDAL.IGeometry,ArchGDAL.IPreparedGeometry,Symbol,Dict{Symbol,Any}}})
    vs = nv(g)
    for v in vertices(g)
        geom = get_prop(g, v, :pointgeom)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, Edge(v, v), (orig=geom, prep=ArchGDAL.preparegeom(geom), type=:vertex, props=props(g, v)))
    end
    for e in edges(g)
        !has_prop(g, e, :edgegeom) && continue
        geom = get_prop(g, e, :edgegeom)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, e, (orig=geom, prep=ArchGDAL.preparegeom(geom), type=:edge, props=props(g, e)))
    end
    return rt
end

end  # module