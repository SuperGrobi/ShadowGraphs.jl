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

const EdgeGeomType = Union{ArchGDAL.IGeometry{ArchGDAL.wkbLineString}, ArchGDAL.IGeometry{ArchGDAL.wkbMultiLineString}}
include("Projection.jl")

export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("BuildGraph.jl")

include("Plotting.jl")

export export_graph_to_csv, import_graph_from_csv
include("Persistence.jl")
end
