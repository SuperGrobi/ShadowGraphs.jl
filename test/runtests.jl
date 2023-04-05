using ShadowGraphs
using LightOSM
using Folium
using Graphs
using MetaGraphs
using ArchGDAL
using CoolWalksUtils
using SpatialIndexing
using Test

include("BuildGraph.jl")
include("Persistence.jl")
include("Plotting.jl")
include("Projection.jl")

@testset "rtree for graphs" begin
    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    rt = build_rtree(g)
end