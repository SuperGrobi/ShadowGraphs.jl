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

@testitem "bearing_histogram" begin
    using MetaGraphs
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

    @test_throws AssertionError bearing_histogram(g)

    unweight_hist = bearing_histogram(g; refresh_bearings=true)
    unweight_hist2 = bearing_histogram(g; refresh_bearings=true)

    bearing_edges = filter_edges(g, :ms_bearing)
    @test !isempty(bearing_edges)

    @test length(unweight_hist.weights) == 36
    @test unweight_hist.edges[1][1] == -5.0

    weighed_hist = bearing_histogram(g; weight=:sg_street_length)
    @test weighed_hist.weights != unweight_hist.weights
    @test unweight_hist.weights == unweight_hist2.weights

    @test length(bearing_histogram(g; nbins=100).weights) == 100

    @test bearing_histogram(g; binshift=100).edges[1][1] == 100
end

@testitem "orientation_entropy" begin
    using StatsBase
    grid_hist = fit(Histogram, [10, 100, 190, 280], 0:10:360)
    @test orientation_entropy(grid_hist) ≈ -log(1 / 4) + log(10)

    grid_hist = fit(Histogram, [10, 100, 190, 280], 0:1:360)
    @test orientation_entropy(grid_hist) ≈ -log(1 / 4) + log(1)

    uniform_hist = fit(Histogram, 0:1:359, 0:10:360)
    @test orientation_entropy(uniform_hist) ≈ log(36) + log(10)

    uniform_hist = fit(Histogram, 0:1:359, 0:5:360)
    @test orientation_entropy(uniform_hist) ≈ log(72) + log(5)
end

@testitem "orientation_order" begin
    using StatsBase
    grid_hist = fit(Histogram, [10, 100, 190, 280], 0:10:360)
    @test ShadowGraphs.orientation_order(grid_hist) ≈ 1.0

    grid_hist = fit(Histogram, [10, 100, 190, 280], 0:1:360)
    @test ShadowGraphs.orientation_order(grid_hist) ≈ 1.0

    uniform_hist = fit(Histogram, 0:1:359, 0:10:360)
    @test ShadowGraphs.orientation_order(uniform_hist) ≈ 0.0 atol = 1e-14

    uniform_hist = fit(Histogram, 0:1:359, 0:5:360)
    @test ShadowGraphs.orientation_order(uniform_hist) ≈ 0.0 atol = 1e-14
end