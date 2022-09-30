module ShadowGraphs
using LightOSM
using LightXML
using Graphs
using MetaGraphs
using ProgressMeter
using ArchGDAL

export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("buildGraph.jl")

end
