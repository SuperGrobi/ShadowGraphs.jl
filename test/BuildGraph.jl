include("./utils/BuildGraphTestUtils.jl")

# PARSING
@testitem "parse width tag" begin
    @test ShadowGraphs.width(Dict(:a => 2)) isa Missing
    @test ShadowGraphs.width(Dict(:a => 2, "width" => missing)) isa Missing
    @test ShadowGraphs.width(Dict(:a => 2, "width" => 4)) == 4
    @test ShadowGraphs.width(Dict(:a => 2, "width" => 4.6)) == 4.6
    @test ShadowGraphs.width(Dict("width" => -4)) == 4

    @test ShadowGraphs.width(Dict("width" => "5")) == 5
    @test ShadowGraphs.width(Dict("width" => "8.53")) == 8.53
    @test ShadowGraphs.width(Dict("width" => "2, 3, 5.9m, 8")) == 8
    @test ShadowGraphs.width(Dict("width" => "6.5meter")) == 6.5
    @test ShadowGraphs.width(Dict("width" => "-6.5 meter, 8m")) == 8
    @test ShadowGraphs.width(Dict("width" => "-6.5meter, -8m")) == 8
end

@testitem "parse_lanes" begin
    using LightOSM
    tags = Dict(
        "lanes" => 4.6,
        "lanes:forward" => 3,
        "lanes:backward" => "4.6",
        "lanes:both_ways" => "3",
        "lanes:missing" => missing
    )
    @test ShadowGraphs.parse_lanes(tags, "lanes") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:forward") == LightOSM.DEFAULT_OSM_LANES_TYPE(3)
    @test ShadowGraphs.parse_lanes(tags, "lanes:backward") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:both_ways") == LightOSM.DEFAULT_OSM_LANES_TYPE(3)
    @test ShadowGraphs.parse_lanes(tags, "lanes:non_mapped") isa Missing
    @test ShadowGraphs.parse_lanes(tags, "lanes:missing") isa Missing

    tags = Dict(
        "lanes" => -4.6,
        "lanes:forward" => -3,
        "lanes:backward" => "-4.6",
        "lanes:both_ways" => "-3",
        "lanes:missing" => missing
    )
    @test ShadowGraphs.parse_lanes(tags, "lanes") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:forward") == LightOSM.DEFAULT_OSM_LANES_TYPE(3)
    @test ShadowGraphs.parse_lanes(tags, "lanes:backward") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:both_ways") == LightOSM.DEFAULT_OSM_LANES_TYPE(3)
    @test ShadowGraphs.parse_lanes(tags, "lanes:non_mapped") isa Missing
    @test ShadowGraphs.parse_lanes(tags, "lanes:missing") isa Missing

    tags = Dict(
        "lanes" => "5 lanes",
        "lanes:forward" => "-5.2lanes",
        "lanes:backward" => "5,6,2.9, 8",
        "lanes:both_ways" => "[1,2,3,4,-12.5]",
    )
    @test ShadowGraphs.parse_lanes(tags, "lanes") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:forward") == LightOSM.DEFAULT_OSM_LANES_TYPE(5)
    @test ShadowGraphs.parse_lanes(tags, "lanes:backward") == LightOSM.DEFAULT_OSM_LANES_TYPE(round((5 + 6 + 2.9 + 8) / 4))
    @test ShadowGraphs.parse_lanes(tags, "lanes:both_ways") == LightOSM.DEFAULT_OSM_LANES_TYPE(round((10 + 12.5) / 5))
end

@testitem "parse_raw_ways" begin
    raw_ways = [
        Dict(  # gets skipped because it is not a highway
            "id" => 1,
            "nodes" => [1, 2, 3, 4, 5],
            "tags" => Dict{String,Any}("nodes" => [1, 2, 3], "lanes" => "4")
        ),
        Dict(  # gets skipped due to network mismatch
            "id" => 2,
            "nodes" => [1, 2, 3, 4, 5],
            "tags" => Dict{String,Any}("highway" => "raceway", "lanes" => "6")
        ),
        Dict(
            "id" => 3,
            "nodes" => [1, 2, 3, 4, 5],
            "tags" => Dict{String,Any}("highway" => "residential", "oneway" => "1", "width" => "10m", "lanes" => "2")
        ),
        Dict(
            "id" => 4,
            "nodes" => [1, 2, 3, 4, 5],
            "tags" => Dict{String,Any}("highway" => "path", "oneway" => "no", "lanes" => "4", "lanes:forward" => 3, "lanes:backward" => "1")
        )
    ]

    parsed = ShadowGraphs.parse_raw_ways(raw_ways, :bike)

    @test length(parsed) == 2
    @test parsed[3].tags["oneway"] == true
    @test parsed[3].tags["reverseway"] == false
    @test parsed[3].tags["width"] == 10
    @test parsed[3].tags["lanes"] == 2
    @test parsed[3].tags["lanes:forward"] isa Missing
    @test parsed[3].tags["lanes:backward"] isa Missing
    @test parsed[3].tags["lanes:both_ways"] isa Missing

    @test parsed[4].tags["oneway"] == false
    @test parsed[4].tags["reverseway"] == false
    @test parsed[4].tags["width"] isa Missing
    @test parsed[4].tags["lanes"] == 4
    @test parsed[4].tags["lanes:forward"] == 3
    @test parsed[4].tags["lanes:backward"] == 1
    @test parsed[4].tags["lanes:both_ways"] isa Missing
end

# PREDICATES
@testitem "is_end_node" begin
    using Graphs, MetaGraphs
    cd(@__DIR__)
    include("./utils/BuildGraphTestUtils.jl")

    g = setup_testgraph()
    solutions = [true, true, true, false, false, false]
    for (node, solution) in zip(vertices(g), solutions)
        @test ShadowGraphs.is_end_node(g, node) == solution
    end
end

@testitem "is_circular_way" begin
    using LightOSM

    w1 = Way(1, [1, 2, 3, 4, 5, 6, 1], Dict("oneway" => true, "isroundabout" => true, "name" => "testroundabout"))
    w2 = Way(2, [7, 8, 9, 10, 11], Dict("oneway" => false, "isroundabout" => false, "highway" => "residential"))
    @test ShadowGraphs.is_circular_way(w1)
    @test !ShadowGraphs.is_circular_way(w2)
end


@testitem "add_this_node" begin
    using LightOSM
    cd(@__DIR__)

    g = graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    @test ShadowGraphs.add_this_node(g, 323204711)  # roundabout, start-end
    @test ShadowGraphs.add_this_node(g, 323203082)  # intersection
    @test ShadowGraphs.add_this_node(g, 323231794)  # lolipop
    @test ShadowGraphs.add_this_node(g, 323204751)  # roundabout exit, non start
    @test ShadowGraphs.add_this_node(g, 322837719)  # lolipop
    @test ShadowGraphs.add_this_node(g, 446038083)  # circle without other exits (on a stick)
    @test ShadowGraphs.add_this_node(g, 2679172848) # end of road
    @test ShadowGraphs.add_this_node(g, 2675918319) # lolipop with broken ring
    @test ShadowGraphs.add_this_node(g, 2675918517) # exit from lolipop

    @test !ShadowGraphs.add_this_node(g, 323204750)  # roundabout non relevant
    @test !ShadowGraphs.add_this_node(g, 323232942)  # start/end of circle, but no entry/exit
    @test !ShadowGraphs.add_this_node(g, 2941956390)  # center of cyclepath
    @test !ShadowGraphs.add_this_node(g, 322834114)   # lolipop, between exits
    @test !ShadowGraphs.add_this_node(g, 2675918248)  # part of lolipop stem
    @test !ShadowGraphs.add_this_node(g, 2675918306)  # roundabout non exit
    @test !ShadowGraphs.add_this_node(g, 323227343)   # some node along street
    @test !ShadowGraphs.add_this_node(g, 1647848982)  # another random node
    @test !ShadowGraphs.add_this_node(g, 323203074)  # another random node
end

# SMALL HELPERS
@testitem "countall" begin
    @test ShadowGraphs.countall([1, 2, 3, 1, 2]) == Dict(1 => 2, 2 => 2, 3 => 1)
    @test ShadowGraphs.countall([1, 1, 1, 1, 1]) == Dict(1 => 5)
    @test ShadowGraphs.countall([1, 2, 3]) == Dict(1 => 1, 2 => 1, 3 => 1)
end

@testitem "get_rotational_direction" begin
    using LightOSM, MetaGraphs
    cd(@__DIR__)

    nodes = Dict(i => Node(i, GeoLocation(lat, lon), nothing) for (i, lon, lat) in zip(1:7, cos.(0:6), sin.(0:6)))

    leftway = Way(1, [1, 2, 3, 4, 5, 6, 1], Dict{String,Any}())
    rightway = Way(1, [5, 4, 1, 7, 5], Dict{String,Any}())
    straightway = Way(1, [5, 6, 4, 7, 1, 2], Dict{String,Any}())

    @test ShadowGraphs.get_rotational_direction(leftway, nodes, 1) == 1
    @test ShadowGraphs.get_rotational_direction(leftway, nodes, -1) == -1
    @test ShadowGraphs.get_rotational_direction(rightway, nodes, 1) == -1
    @test ShadowGraphs.get_rotational_direction(rightway, nodes, -1) == 1

    @test ShadowGraphs.get_rotational_direction(straightway, nodes, 1) == 0
    @test ShadowGraphs.get_rotational_direction(straightway, nodes, -1) == 0

    g = shadow_graph_from_file("./data/test_clifton_bike.json", network_type=:bike)
    @test get_prop(g, :sg_offset_dir) == -1
end


# DECOMPOSITION AND GEOMETRY CONSTRUCTION
@testitem "decompose_way_to_primitives" begin
    using LightOSM

    line = Way(1, [10, 20, 30, 40, 50, 60, 70, 80], Dict("oneway" => false, "reverseway" => false, "name" => "line"))
    ring = Way(2, [10, 20, 30, 40, 50, 60, 70, 80, 10], Dict("oneway" => false, "reverseway" => false, "name" => "ring"))
    loli = Way(3, [10, 20, 30, 40, 50, 60, 70, 30], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
    loli_reverse = Way(4, [10, 20, 30, 40, 10, 50, 60], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
    stresstest_open = Way(5, [10, 20, 30, 40, 50, 60, 70, 50, 30, 80, 90], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
    stresstest_closed = Way(6, [10, 20, 30, 40, 20, 50, 60, 60, 70, 10], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
    clover = Way(7, [10, 20, 30, 40, 20, 50, 60, 20, 70, 80, 20], Dict("oneway" => false, "reverseway" => false, "name" => "clover"))


    line_decomp = ShadowGraphs.decompose_way_to_primitives(line)
    ring_decomp = ShadowGraphs.decompose_way_to_primitives(ring)
    loli_decomp = ShadowGraphs.decompose_way_to_primitives(loli)
    loli_reverse_decomp = ShadowGraphs.decompose_way_to_primitives(loli_reverse)
    stresstest_open_decomp = ShadowGraphs.decompose_way_to_primitives(stresstest_open)
    stresstest_closed_decomp = ShadowGraphs.decompose_way_to_primitives(stresstest_closed)
    clover_decomp = ShadowGraphs.decompose_way_to_primitives(clover)

    @test length(line_decomp) == 1
    @test line_decomp[1].id == line.id
    @test line_decomp[1].nodes == line.nodes

    @test length(ring_decomp) == 1
    @test ring_decomp[1].id == ring.id
    @test ring_decomp[1].nodes == ring.nodes

    @test length(loli_decomp) == 2
    @test all([i.id == loli.id for i in loli_decomp])
    @test loli_decomp[1].nodes == [10, 20, 30]
    @test loli_decomp[2].nodes == [30, 40, 50, 60, 70, 30]

    @test length(loli_reverse_decomp) == 2
    @test all([i.id == loli_reverse.id for i in loli_reverse_decomp])
    @test loli_reverse_decomp[1].nodes == [10, 20, 30, 40, 10]
    @test loli_reverse_decomp[2].nodes == [10, 50, 60]

    @test length(stresstest_open_decomp) == 5
    @test all([i.id == stresstest_open.id for i in stresstest_open_decomp])
    @test stresstest_open_decomp[1].nodes == [10, 20, 30]
    @test stresstest_open_decomp[2].nodes == [30, 40, 50]
    @test stresstest_open_decomp[3].nodes == [50, 60, 70, 50]
    @test stresstest_open_decomp[4].nodes == [50, 30]
    @test stresstest_open_decomp[5].nodes == [30, 80, 90]

    @test length(stresstest_closed_decomp) == 4
    @test all([i.id == stresstest_closed.id for i in stresstest_closed_decomp])
    @test stresstest_closed_decomp[1].nodes == [20, 30, 40, 20]
    @test stresstest_closed_decomp[2].nodes == [20, 50, 60]
    @test stresstest_closed_decomp[3].nodes == [60, 60]
    @test stresstest_closed_decomp[4].nodes == [60, 70, 10, 20]

    @test length(clover_decomp) == 4
    @test all([i.id == clover.id for i in clover_decomp])
    @test clover_decomp[1].nodes == [10, 20]
    @test clover_decomp[2].nodes == [20, 30, 40, 20]
    @test clover_decomp[3].nodes == [20, 50, 60, 20]
    @test clover_decomp[4].nodes == [20, 70, 80, 20]
end

@testitem "get_all_node_lists lines" begin
    using LightOSM

    line = Way(1, [10, 20, 30, 40, 50, 60, 70, 80], Dict("oneway" => false, "reverseway" => false, "name" => "line"))

    topo_nodes = [10, 40, 50, 70, 80]

    all_node_lists = ShadowGraphs.get_all_node_lists(line, topo_nodes)
    expected_nodes = [[10, 20, 30, 40], [40, 50], [50, 60, 70], [70, 80]]

    @test length(all_node_lists) == length(expected_nodes)
    for (result, expected) in zip(all_node_lists, expected_nodes)
        @test result == expected
    end

    @test_throws AssertionError ShadowGraphs.get_all_node_lists(Way(2, [10, 20, 30, 40, 20, 50, 10, 60], Dict{String,Any}()), [20, 40, 50])  # non simple way
    @test_throws AssertionError ShadowGraphs.get_all_node_lists(Way(2, [10, 20, 30, 40, 20], Dict{String,Any}()), [10, 20, 40])  # non simple way with one duplicate
end

@testitem "get_all_node_lists rings" begin
    using LightOSM

    ring = Way(1, [10, 20, 30, 40, 50, 60, 70, 80, 10], Dict("oneway" => false, "reverseway" => false, "name" => "ring"))


    topo_nodes_unbroken = [10]
    @test ShadowGraphs.get_all_node_lists(ring, topo_nodes_unbroken) == [[10, 20, 30, 40, 50, 60, 70, 80, 10]]

    topo_nodes_unbroken = [40]
    @test ShadowGraphs.get_all_node_lists(ring, topo_nodes_unbroken) == [[40, 50, 60, 70, 80, 10, 20, 30, 40]]

    # start is part of topology
    topo_nodes_broken = [10, 40, 60, 70]
    all_node_lists = ShadowGraphs.get_all_node_lists(ring, topo_nodes_broken)
    expected_nodes = [[10, 20, 30, 40], [40, 50, 60], [60, 70], [70, 80, 10]]

    @test length(all_node_lists) == length(expected_nodes)
    for (result, expected) in zip(all_node_lists, expected_nodes)
        @test result == expected
    end

    # start is not part of topology
    topo_nodes_broken = [20, 50, 60, 80]

    all_node_lists = ShadowGraphs.get_all_node_lists(ring, topo_nodes_broken)
    expected_nodes = [[20, 30, 40, 50], [50, 60], [60, 70, 80], [80, 10, 20]]

    @test length(all_node_lists) == length(expected_nodes)
    for (result, expected) in zip(all_node_lists, expected_nodes)
        @test result == expected
    end

    @test_throws AssertionError ShadowGraphs.get_all_node_lists(Way(2, [10, 20, 30, 40, 20, 50, 10], Dict{String,Any}()), [20, 40, 50])  # non simple way
    @test_throws AssertionError ShadowGraphs.get_all_node_lists(Way(2, [10, 20, 30, 40, 50, 20], Dict{String,Any}()), [10, 20, 40])  # non simple way with one duplicate
end


@testitem "geolinestring from osm nodes" begin
    using LightOSM, ArchGDAL, CoolWalksUtils

    lons = [2.0, 4.0, 5.8, 9.9, 8.4, -6.3, -1.4, 4.8, -2.8, 2.0]
    lats = [8.2, -3.1, -2.9, -8.0, -4.3, 2.7, -8.5, 7.5, 3.0, -9.5]
    tags = Dict("a" => 1, "b" => "hi")
    nodes = Dict(i => Node(i, GeoLocation(lat, lon), tags) for (i, lon, lat) in zip(1:10, lons, lats))

    ls1 = ShadowGraphs.geolinestring(nodes, [4, 7, 1, 8])
    ls2 = ShadowGraphs.geolinestring(nodes, [8, 9, 1, 6, 7, 4])
    ls3 = ShadowGraphs.geolinestring(nodes, [7, 9, 6, 7])
    ls4 = ShadowGraphs.geolinestring(nodes, [1, 2, 3, 5, 1])

    @test ArchGDAL.ngeom(ls1) == 4
    @test ArchGDAL.ngeom(ls2) == 6
    @test ArchGDAL.ngeom(ls3) == 4
    @test ArchGDAL.ngeom(ls4) == 5

    for l in [ls1, ls2, ls3, ls4]
        @test repr(ArchGDAL.getspatialref(l)) == repr(OSM_ref[])
    end

    @test ArchGDAL.getx(ls1, 3) ≈ 4.8
    @test ArchGDAL.getx(ls2, 3) ≈ -6.3
    @test ArchGDAL.getx(ls3, 3) ≈ -1.4
    @test ArchGDAL.getx(ls4, 3) ≈ 8.4

    @test ArchGDAL.distance(ArchGDAL.pointalongline(ls3, 0), ArchGDAL.pointalongline(ls3, ArchGDAL.geomlength(ls3))) ≈ 0 atol = 1e-13
    @test ArchGDAL.distance(ArchGDAL.pointalongline(ls4, 0), ArchGDAL.pointalongline(ls4, ArchGDAL.geomlength(ls4))) ≈ 0 atol = 1e-13
end


# incremental addition of edges
@testitem "add_edge_with_data" begin
    using ArchGDAL, MetaGraphs, Graphs, CoolWalksUtils
    cd(@__DIR__)
    include("./utils/BuildGraphTestUtils.jl")

    function data(g, s, d)
        xs = get_prop(g, s, :sg_lon)
        ys = get_prop(g, s, :sg_lat)
        xd = get_prop(g, d, :sg_lon)
        yd = get_prop(g, d, :sg_lat)
        x = [xs, (xs + xd) / 2 + 0.3 * (indegree(g, d) + 1), (xs + xd) / 2 - 0.5 * (indegree(g, d) + 1), xd]
        y = [ys, (ys + yd) / 2 - 0.1 * (outdegree(g, s) + 1), (ys + yd) / 2 + 0.2 * (outdegree(g, s) + 1), yd]
        line = ArchGDAL.createlinestring(x, y)
        apply_wsg_84!(line)
        return Dict(:a => 1, :b => 2, :sg_street_geometry => line)
    end

    g = setup_addingraph()
    # simple edge
    ShadowGraphs.add_edge_with_data!(g, 1, 3, data=data(g, 1, 3))
    @test has_edge(g, 1, 3)
    @test !has_edge(g, 3, 1)
    @test get_prop(g, 1, 3, :a) == 1
    @test get_prop(g, 1, 3, :b) == 2
    @test ne(g) == 1

    # simple edge
    ShadowGraphs.add_edge_with_data!(g, 3, 4, data=data(g, 3, 4))
    @test has_edge(g, 3, 4)
    @test !has_edge(g, 4, 3)
    @test get_prop(g, 3, 4, :a) == 1
    @test get_prop(g, 3, 4, :b) == 2
    @test ne(g) == 2

    # multi edge
    ShadowGraphs.add_edge_with_data!(g, 1, 3, data=data(g, 1, 3))
    @test ne(g) == 4
    @test has_vertex(g, 6)
    @test has_edge(g, 1, 6)
    @test has_edge(g, 6, 3)

    @test get_prop(g, 6, :sg_helper)
    @test get_prop(g, 1, 6, :sg_helper)
    @test get_prop(g, 6, 3, :a) == 1
    @test get_prop(g, 6, 3, :b) == 2

    # self edge
    ShadowGraphs.add_edge_with_data!(g, 2, 2, data=data(g, 2, 2))
    @test ne(g) == 7
    @test has_vertex(g, 7)
    @test has_vertex(g, 8)
    @test has_edge(g, 2, 7)
    @test has_edge(g, 7, 8)
    @test has_edge(g, 8, 2)

    @test get_prop(g, 7, :sg_helper)
    @test get_prop(g, 8, :sg_helper)
    @test get_prop(g, 2, 7, :sg_helper)
    @test get_prop(g, 8, 2, :sg_helper)

    @test get_prop(g, 7, 8, :a) == 1
    @test get_prop(g, 7, 8, :b) == 2

    # adding edges to node without lon and lat props
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 3, data=data(g, 5, 3))
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 3, 5, data=data(g, 3, 5))
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 5, data=data(g, 5, 5))
    @test add_edge!(g, 4, 5)
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 4, 5, data=Dict(:a => 1, :b => 2))
end

# MAIN ENTRY POINT FOR GRAPH CONSTRUCTION
@testitem "shadow_graph_from_light_osm_graph" begin
    using MetaGraphs, Graphs, ArchGDAL, LightOSM, TimeZones
    cd(@__DIR__)

    g_osm = graph_from_file("./data/test_clifton_bike.json", network_type=:bike)
    g = ShadowGraphs.shadow_graph_from_light_osm_graph(g_osm; timezone=tz"Europe/London")
    @test g isa MetaDiGraph
    @test defaultweight(g) == 0.0
    @test weightfield(g) == :sg_street_length
    @test nv(g) == 1692
    @test ne(g) == 3758
    test_edges = first(edges(g), 5)
    for e in test_edges
        @test has_prop(g, e, :sg_street_length)
        @test get_prop(g, e, :sg_street_length) > 0
        @test ArchGDAL.distance(get_prop(g, e, :sg_street_geometry), get_prop(g, e, :sg_geometry_base)) ≈ 0 atol = 1e-10
        @test ArchGDAL.geomlength(get_prop(g, e, :sg_street_geometry)) ≈ ArchGDAL.geomlength(get_prop(g, e, :sg_geometry_base))
    end
    @test mapreduce(e -> has_prop(g, e, :sg_street_geometry) && has_prop(g, e, :sg_geometry_base), &, filter_edges(g, :sg_helper, false))

    # test if all relevant props are set
    @test has_prop(g, :sg_crs)
    @test has_prop(g, :sg_offset_dir)
    @test has_prop(g, :sg_observatory)
    @test get_prop(g, :sg_observatory).tz == tz"Europe/London"
end

# USER FACING LOADER FUNCTIONS
@testitem "shadow_graph_from_object" begin
    using LightOSM, MetaGraphs, Graphs, TimeZones
    cd(@__DIR__)

    obj = LightOSM.file_deserializer("./data/test_clifton_bike.json")("./data/test_clifton_bike.json")
    g = shadow_graph_from_object(obj, network_type=:bike, timezone=tz"Europe/Berlin")
    @test g isa MetaDiGraph
    @test nv(g) == 1692
    @test ne(g) == 3758
    @test get_prop(g, :sg_observatory).tz == tz"Europe/Berlin"
end

@testitem "shadow_graph_from_file" begin
    using MetaGraphs, Graphs, TimeZones
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json", network_type=:bike)
    @test g isa MetaDiGraph
    @test nv(g) == 1692
    @test ne(g) == 3758

    @test get_prop(g, :sg_observatory).tz == tz"Europe/London"

    g = shadow_graph_from_file("./data/test_clifton_bike.json", network_type=:bike, timezone=tz"Europe/Berlin")

    @test get_prop(g, :sg_observatory).tz == tz"Europe/Berlin"
end

@testitem "shadow_graph_from_download" begin
    using MetaGraphs, Graphs, CoolWalksUtils, TimeZones

    @rerun 15 begin
        g = shadow_graph_from_download(:bbox; minlat=52.89, minlon=-1.2, maxlat=52.92, maxlon=-1.165, network_type=:bike)
        @test g isa MetaDiGraph
        # very weak test, but that is about as much as I can guarantee.
        @test nv(g) > 0
        @test ne(g) > 0
        @test get_prop(g, :sg_observatory).tz == tz"Europe/London"
    end

    @rerun 15 begin
        g = shadow_graph_from_download(:bbox; timezone=tz"America/New_York", minlat=52.89, minlon=-1.2, maxlat=52.92, maxlon=-1.165, network_type=:bike)
        @test g isa MetaDiGraph
        # very weak test, but that is about as much as I can guarantee.
        @test nv(g) > 0
        @test ne(g) > 0
        @test get_prop(g, :sg_observatory).tz == tz"America/New_York"
    end
end