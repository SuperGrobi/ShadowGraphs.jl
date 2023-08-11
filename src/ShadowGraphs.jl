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
using LinearAlgebra


# TODO: Rework Measures

const EdgeShadowGeomType = Union{ArchGDAL.IGeometry{ArchGDAL.wkbLineString},ArchGDAL.IGeometry{ArchGDAL.wkbMultiLineString}}
const EdgeStreetGeomType = ArchGDAL.IGeometry{ArchGDAL.wkbLineString}
const VertexGeomType = ArchGDAL.IGeometry{ArchGDAL.wkbPoint}

include("Projection.jl")

export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("BuildGraph.jl")

include("Plotting.jl")
include("RTreeBuilding.jl")

export export_shadow_graph_to_csv, import_shadow_graph_from_csv
include("Persistence.jl")

export tag_edge_bearings!, bearing_histogram, orientation_entropy
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


# overloads which should be in Graphs and MetaGraphs
outedges(g, v) = Edge.(v, outneighbors(g, v))
inedges(g, v) = Edge.(inneighbors(g, v), v)
get_prop_default(g, e, p, default) = has_prop(g, e, p) ? get_prop(g, e, p) : default
export outedges, inedges, get_prop_default

end  # module