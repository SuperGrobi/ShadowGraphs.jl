@testitem "rtree for graphs" begin
    using ArchGDAL, CoolWalksUtils, MetaGraphs, SpatialIndexing
    cd(@__DIR__)

    rect_mask(x, y, dx, dy) = ArchGDAL.createpolygon([x, x + dx, x + dx, x, x], [y, y, y + dy, y + dy, y])
    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    mask1 = rect_mask(400.0, 350.0, 160.0, 140.0)
    mask2 = rect_mask(540.0, -450.0, 100.0, 100.0)
    project_local!(g)
    foreach(m -> reinterp_crs!(m, get_prop(g, :sg_crs)), [mask1, mask2])
    rt = build_rtree(g)

    # large mask containing a lot of stuff around an intersection
    tree_intersections_mask1 = intersects_with(rt, rect_from_geom(mask1)) |> collect
    tree_contained_mask1 = contained_in(rt, rect_from_geom(mask1)) |> collect

    @test length(tree_intersections_mask1) == 153
    @test length(tree_contained_mask1) == 138

    @test count(i -> i.val.type == :vertex, tree_intersections_mask1) == 42
    @test count(i -> i.val.type == :edge, tree_intersections_mask1) == 111
    @test count(i -> i.val.type == :vertex, tree_contained_mask1) == 42
    @test count(i -> i.val.type == :edge, tree_contained_mask1) == 96

    actually_intersect_mask1 = filter(i -> ArchGDAL.intersects(i.val.orig, mask1), tree_intersections_mask1)
    @test length(actually_intersect_mask1) == 151
    actually_intersect_contained_mask1 = filter(i -> ArchGDAL.intersects(i.val.orig, mask1), tree_contained_mask1)
    @test length(actually_intersect_contained_mask1) == 138

    # small mask, with (humanly) countable things in it
    tree_intersections_mask2 = intersects_with(rt, rect_from_geom(mask2)) |> collect
    tree_contained_mask2 = contained_in(rt, rect_from_geom(mask2)) |> collect

    @test length(tree_intersections_mask2) == 15
    @test length(tree_contained_mask2) == 7

    @test count(i -> i.val.type == :vertex, tree_intersections_mask2) == 5
    @test count(i -> i.val.type == :edge, tree_intersections_mask2) == 10

    @test count(i -> i.val.type == :vertex, tree_contained_mask2) == 5
    @test count(i -> i.val.type == :edge, tree_contained_mask2) == 2

    actually_intersect_mask2 = filter(i -> ArchGDAL.intersects(i.val.orig, mask2), tree_intersections_mask2)
    @test length(actually_intersect_mask2) == 11
    actually_intersect_contained_mask2 = filter(i -> ArchGDAL.intersects(i.val.orig, mask2), tree_contained_mask2)
    @test length(actually_intersect_contained_mask2) == 7

    project_back!([mask1, mask2])
    project_back!(g)
end