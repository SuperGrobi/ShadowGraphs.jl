@testitem "tag_edge_bearings!" begin
    using MetaGraphs
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

    bearing_edges = filter_edges(g, :ms_bearing)
    @test isempty(bearing_edges)

    tag_edge_bearings!(g)
    bearing_edges = filter_edges(g, :ms_bearing)
    @test !isempty(bearing_edges)
end

@testitem "single_bearing" begin
    using ArchGDAL
    l1 = ArchGDAL.createlinestring([0, 0], [0, 1])  # ⬆
    l2 = ArchGDAL.createlinestring([0, 1], [0, 0])  # ➡
    l3 = ArchGDAL.createlinestring([0, 0], [0, -1])  # ⬇
    l4 = ArchGDAL.createlinestring([0, -1], [0, 0])  # ⬅

    l5 = ArchGDAL.createlinestring([0, 1], [0, 1])  # ↗
    l6 = ArchGDAL.createlinestring([0, 1], [0, -1])  # ↘
    l7 = ArchGDAL.createlinestring([0, -1], [0, -1])  # ↙
    l8 = ArchGDAL.createlinestring([0, -1], [0, 1])  # ↖

    @test ShadowGraphs.single_bearing(l1) ≈ 0.0
    @test ShadowGraphs.single_bearing(l2) ≈ 90.0
    @test ShadowGraphs.single_bearing(l3) ≈ 180.0
    @test ShadowGraphs.single_bearing(l4) ≈ 270.0

    @test ShadowGraphs.single_bearing(l5) ≈ 45.0
    @test ShadowGraphs.single_bearing(l6) ≈ 135.0
    @test ShadowGraphs.single_bearing(l7) ≈ 225.0
    @test ShadowGraphs.single_bearing(l8) ≈ 315.0
end