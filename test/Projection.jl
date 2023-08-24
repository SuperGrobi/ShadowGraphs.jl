@testitem "Graph Projection basics" begin
    using MetaGraphs, Graphs, CoolWalksUtils, ArchGDAL, TimeZones
    g = MetaDiGraph()

    @test_throws KeyError project_local!(g, 1.0, 2.0)  # no crs set
    set_prop!(g, :sg_crs, OSM_ref[])

    g_proj = project_local!(g, 1.0, 2.0)
    @test g_proj === g
    @test contains(repr(get_prop(g, :sg_crs)), "proj=tmerc")
    g_back = project_back!(g)
    @test g_back === g
    @test repr(get_prop(g, :sg_crs)) == repr(OSM_ref[])

    add_vertex!(g, Dict(:a => ArchGDAL.createpoint(1.0, 2.0), :b => "test"))
    add_vertex!(g, Dict(:sg_geometry => ArchGDAL.createpoint(5.0, 9.0), :tuple => (1, 2)))
    add_vertex!(g, Dict(:pointgeom => ArchGDAL.createpoint(5.0, 9.0), :list => [1, 3]))

    add_edge!(g, 1, 2, Dict(:line => ArchGDAL.createlinestring([1.0, 3.0, 5.0], [2.0, 7.3, 9.0]), :name => "name"))
    add_edge!(g, 1, 3, Dict(:name => "nonstreet", :length => 12.5))

    project_local!(g, 1.0, 2.0)
    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 0
    @test get_prop(g, 1, :b) == "test"

    @test !(ArchGDAL.getx(get_prop(g, 2, :sg_geometry), 0) ≈ 5.0)
    @test !(ArchGDAL.gety(get_prop(g, 2, :sg_geometry), 0) ≈ 9.0)
    @test get_prop(g, 2, :tuple) == (1, 2)

    @test !(ArchGDAL.getx(get_prop(g, 3, :pointgeom), 0) ≈ 5.0)
    @test !(ArchGDAL.gety(get_prop(g, 3, :pointgeom), 0) ≈ 9.0)
    @test get_prop(g, 3, :list) == [1, 3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) > 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test contains(repr(get_prop(g, :sg_crs)), "proj=tmerc")

    project_back!(g)

    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 1.0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 2.0
    @test get_prop(g, 1, :b) == "test"
    @test ArchGDAL.getx(get_prop(g, 2, :sg_geometry), 0) ≈ 5.0
    @test ArchGDAL.gety(get_prop(g, 2, :sg_geometry), 0) ≈ 9.0
    @test get_prop(g, 2, :tuple) == (1, 2)
    @test ArchGDAL.getx(get_prop(g, 3, :pointgeom), 0) ≈ 5.0
    @test ArchGDAL.gety(get_prop(g, 3, :pointgeom), 0) ≈ 9.0
    @test get_prop(g, 3, :list) == [1, 3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) < 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test repr(get_prop(g, :sg_crs)) == repr(OSM_ref[])

    # project with default graph props
    set_prop!(g, :sg_observatory, ShadowObservatory("testobs", 1.0, 2.0, tz"Europe/Berlin"))
    set_prop!(g, :center_lat, 2.0)
    project_local!(g)
    @test g_proj === g
    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 0
    @test get_prop(g, 1, :b) == "test"
    @test !(ArchGDAL.getx(get_prop(g, 2, :sg_geometry), 0) ≈ 5.0)
    @test !(ArchGDAL.gety(get_prop(g, 2, :sg_geometry), 0) ≈ 9.0)
    @test get_prop(g, 2, :tuple) == (1, 2)
    @test !(ArchGDAL.getx(get_prop(g, 3, :pointgeom), 0) ≈ 5.0)
    @test !(ArchGDAL.gety(get_prop(g, 3, :pointgeom), 0) ≈ 9.0)
    @test get_prop(g, 3, :list) == [1, 3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) > 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test contains(repr(get_prop(g, :sg_crs)), "proj=tmerc")

    g_back = project_back!(g)
    @test g_back === g

    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 1.0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 2.0
    @test get_prop(g, 1, :b) == "test"
    @test ArchGDAL.getx(get_prop(g, 2, :sg_geometry), 0) ≈ 5.0
    @test ArchGDAL.gety(get_prop(g, 2, :sg_geometry), 0) ≈ 9.0
    @test get_prop(g, 2, :tuple) == (1, 2)
    @test ArchGDAL.getx(get_prop(g, 3, :pointgeom), 0) ≈ 5.0
    @test ArchGDAL.gety(get_prop(g, 3, :pointgeom), 0) ≈ 9.0
    @test get_prop(g, 3, :list) == [1, 3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) < 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test repr(get_prop(g, :sg_crs)) == repr(OSM_ref[])
end

@testitem "Graph projection real" begin
    using CoolWalksUtils, ArchGDAL, MetaGraphs
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

    @test repr(get_prop(g, :sg_crs)) == repr(OSM_ref[])

    global_before_lengths = [ArchGDAL.geomlength(get_prop(g, e, :sg_street_geometry)) for e in filter_edges(g, :sg_street_geometry)]
    project_local!(g)

    local_lengths = [ArchGDAL.geomlength(get_prop(g, e, :sg_street_geometry)) for e in filter_edges(g, :sg_street_geometry)]
    @test all(local_lengths .> global_before_lengths)
    @test contains(repr(get_prop(g, :sg_crs)), "proj=tmerc")
    ShadowGraphs.check_shadow_graph_integrity(g; strict=true)

    project_back!(g)
    global_after_lengths = [ArchGDAL.geomlength(get_prop(g, e, :sg_street_geometry)) for e in filter_edges(g, :sg_street_geometry)]

    global_diff = abs.(global_after_lengths .- global_before_lengths)
    @test all(global_diff .< 1e-13)
    ShadowGraphs.check_shadow_graph_integrity(g; strict=true)
    @test repr(get_prop(g, :sg_crs)) == repr(OSM_ref[])
end