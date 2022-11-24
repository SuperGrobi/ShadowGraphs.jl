function setup_testgraph()
    es = [(2, 4), (3, 4),(4, 1),(4, 3),(4, 6),(5, 4),(5, 6),(6, 4)]
    g = MetaDiGraph(6)
    for (s, d) in es
        add_edge!(g, s, d)
    end
    return g
end


function setup_addingraph()
    g = MetaDiGraph(4)
    lats = [-3.9, -0.8, -6.4, 6.2]
    lons = [6.7, -3.6, 3.6, -2.4]
    for n in vertices(g)
        set_prop!(g, n, :lon, lons[n])
        set_prop!(g, n, :lat, lats[n])
    end
    add_vertex!(g)
    return g
end


@testset "ShadowGraph creation" begin
    @test "width"
    @test "parse_lanes"
    @test "parse_raw_ways"

    @testset "is_end_node" begin
        g = setup_testgraph()
        solutions = [true, true, true, false, false, false]
        for (node, solution) in zip(vertices(g), solutions)
            @test ShadowGraphs.is_end_node(g, node) == solution
        end
    end


    @testset "add_edge_with_data" begin
        function data(g, s, d)
            xs = get_prop(g, s, :lon)
            ys = get_prop(g, s, :lat)
            xd = get_prop(g, d, :lon)
            yd = get_prop(g, d, :lat)
            x = [xs, (xs+xd)/2 + 0.3 * (indegree(g, d)+1), (xs+xd)/2 - 0.5 * (indegree(g, d)+1), xd]
            y = [ys, (ys+yd)/2 - 0.1 * (outdegree(g, s)+1), (ys+yd)/2 + 0.2 * (outdegree(g, s)+1), yd]
            line = ArchGDAL.createlinestring(x, y)
            apply_wsg_84!(line)
            return Dict(:a => 1, :b => 2, :edgegeom => line)
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

        @test get_prop(g, 6, :helper)
        @test get_prop(g, 1, 6, :helper)
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

        @test get_prop(g, 7, :helper)
        @test get_prop(g, 8, :helper)
        @test get_prop(g, 2, 7, :helper)
        @test get_prop(g, 8, 2, :helper)
        
        @test get_prop(g, 7, 8, :a) == 1
        @test get_prop(g, 7, 8, :b) == 2

        # adding edges to node without lon and lat props
        @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 3, data=data(g, 5, 3))
        @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 3, 5, data=data(g, 3, 5))
        @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 5, data=data(g, 5, 5))
        @test add_edge!(g, 4, 5)
        @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 4, 5, data=Dict(:a=>1, :b=>2))
    end


    @testset "is_circular_way" begin
        w1 = Way(1, [1,2,3,4,5,6,1], Dict("oneway"=>true, "isroundabout"=>true, "name" => "testroundabout"))
        w2 = Way(2, [7,8,9,10,11], Dict("oneway"=>false, "isroundabout"=>false, "highway" => "residential"))
        @test ShadowGraphs.is_circular_way(w1)
        @test !ShadowGraphs.is_circular_way(w2)
    end
    

    @testset "countall" begin
        @test ShadowGraphs.countall([1,2,3,1,2]) == Dict(1=>2, 2=>2, 3=>1)
        @test ShadowGraphs.countall([1,1,1,1,1]) == Dict(1=>5)
        @test ShadowGraphs.countall([1,2,3]) == Dict(1=>1, 2=>1, 3=>1)
    end


    @testset "decompose_way_to_primitives" begin
        line = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line"))
        ring = Way(2, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring"))
        loli = Way(3, [10,20,30,40,50,60,70, 30], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
        loli_reverse = Way(4, [10,20,30,40,10, 50, 60], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
        stresstest_open = Way(5, [10, 20, 30, 40, 50, 60, 70, 50, 30, 80, 90], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
        stresstest_closed = Way(6, [10, 20, 30, 40, 20, 50, 60, 60, 70, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
        clover = Way(7, [10, 20, 30, 40, 20, 50, 60, 20, 70, 80, 20], Dict("oneway"=>false, "reverseway"=>false, "name"=>"clover"))

        
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
        @test loli_decomp[1].nodes == [10,20,30]
        @test loli_decomp[2].nodes == [30,40,50,60,70,30]

        @test length(loli_reverse_decomp) == 2
        @test all([i.id == loli_reverse.id for i in loli_reverse_decomp])
        @test loli_reverse_decomp[1].nodes == [10,20,30,40,10]
        @test loli_reverse_decomp[2].nodes == [10,50,60]

        @test length(stresstest_open_decomp) == 5
        @test all([i.id == stresstest_open.id for i in stresstest_open_decomp])
        @test stresstest_open_decomp[1].nodes == [10,20,30]
        @test stresstest_open_decomp[2].nodes== [30,40,50]
        @test stresstest_open_decomp[3].nodes == [50,60,70,50]
        @test stresstest_open_decomp[4].nodes == [50,30]
        @test stresstest_open_decomp[5].nodes == [30,80,90]

        @test length(stresstest_closed_decomp) == 4
        @test all([i.id == stresstest_closed.id for i in stresstest_closed_decomp])
        @test stresstest_closed_decomp[1].nodes == [20,30,40,20]
        @test stresstest_closed_decomp[2].nodes == [20,50,60]
        @test stresstest_closed_decomp[3].nodes == [60,60]
        @test stresstest_closed_decomp[4].nodes == [60,70,10,20]

        @test length(clover_decomp) == 4
        @test all([i.id == clover.id for i in clover_decomp])
        @test clover_decomp[1].nodes == [10, 20]
        @test clover_decomp[2].nodes == [20,30,40,20]
        @test clover_decomp[3].nodes == [20,50,60,20]
        @test clover_decomp[4].nodes == [20,70,80,20]
    end


    @testset "geolinestring" begin
        lons = [2.0, 4.0, 5.8, 9.9, 8.4, -6.3, -1.4, 4.8, -2.8, 2.0]
        lats = [8.2, -3.1, -2.9, -8.0, -4.3, 2.7, -8.5, 7.5, 3.0, -9.5]
        tags = Dict("a"=>1, "b"=>"hi")
        nodes = Dict(i=>Node(i, GeoLocation(lat, lon), tags) for (i, lon, lat) in zip(1:10, lons, lats))

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

        @test ArchGDAL.distance(ArchGDAL.pointalongline(ls3, 0), ArchGDAL.pointalongline(ls3, ArchGDAL.geomlength(ls3))) ≈ 0 atol=1e-13
        @test ArchGDAL.distance(ArchGDAL.pointalongline(ls4, 0), ArchGDAL.pointalongline(ls4, ArchGDAL.geomlength(ls4))) ≈ 0 atol=1e-13
    end


    @testset "get_rotational_direction" begin
        nodes = Dict(i=>Node(i, GeoLocation(lat, lon), nothing) for (i, lon, lat) in zip(1:7, cos.(0:6), sin.(0:6)))

        leftway = Way(1, [1,2,3,4,5,6,1], Dict{String, Any}())
        rightway = Way(1, [5,4,1,7,5], Dict{String, Any}())
        straightway = Way(1, [5,6,4,7,1,2], Dict{String, Any}())

        @test ShadowGraphs.get_rotational_direction(leftway, nodes, 1) == 1
        @test ShadowGraphs.get_rotational_direction(leftway, nodes, -1) == -1
        @test ShadowGraphs.get_rotational_direction(rightway, nodes, 1) == -1
        @test ShadowGraphs.get_rotational_direction(rightway, nodes, -1) == 1
        
        @test ShadowGraphs.get_rotational_direction(straightway, nodes, 1) == 0
        @test ShadowGraphs.get_rotational_direction(straightway, nodes, -1) == 0

        g = shadow_graph_from_file("./data/test_clifton_bike.json", network_type=:bike)
        @test get_prop(g, :offset_dir) == -1 
    end


    @testset "add_this_node" begin
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


    @testset "get_node_list lines" begin
        line = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line"))

        topo_nodes = [10, 40, 50, 70, 80]
        
        @test ShadowGraphs.get_node_list(line, 10, topo_nodes, 1) == [10, 20, 30, 40]
        @test ShadowGraphs.get_node_list(line, 50, topo_nodes, 1) == [50, 60, 70]
        @test ShadowGraphs.get_node_list(line, 70, topo_nodes, 1) == [70, 80]
        
        @test ShadowGraphs.get_node_list(line, 80, topo_nodes, -1) == [80, 70]
        @test ShadowGraphs.get_node_list(line, 70, topo_nodes, -1) == [70,60,50]
        @test ShadowGraphs.get_node_list(line, 40, topo_nodes, -1) == [40,30,20, 10]
        
        @test ShadowGraphs.get_node_list(line, 80, topo_nodes, 1) === nothing
        @test ShadowGraphs.get_node_list(line, 10, topo_nodes, -1) === nothing
        
        @test_throws ArgumentError ShadowGraphs.get_node_list(line, 20, topo_nodes, 2)  # direction not allowed
        @test_throws ArgumentError ShadowGraphs.get_node_list(line, 25, topo_nodes, 1)  # start not in way
        @test_throws ArgumentError ShadowGraphs.get_node_list(line, 20, topo_nodes, 1)  # start not in topo nodes
        @test_throws ArgumentError ShadowGraphs.get_node_list(line, 10, [10, 40, 50, 90], 1)  # topo nodes not subset of way
        
        @test_throws ArgumentError ShadowGraphs.get_node_list(Way(2, [10,20,30,40,20,50,10,60], Dict{String, Any}()), 20, [20, 40, 50], 1)  # non simple way
        @test_throws ArgumentError ShadowGraphs.get_node_list(Way(2, [10,20,30,40,20], Dict{String, Any}()), 20, [10, 20, 40], 1)  # non simple way with one duplicate
    end

    @testset "get_node_list rings" begin
        ring = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring"))

        topo_nodes_unbroken = [10, 10]
        @test ShadowGraphs.get_node_list(ring, 10, topo_nodes_unbroken, 1) == [10,20,30,40,50,60,70,80,10]
        @test ShadowGraphs.get_node_list(ring, 10, topo_nodes_unbroken, -1) == [10,80,70,60,50,40,30,20,10]

        # start is part of topology
        topo_nodes_broken = [10,40,60,70,10]
        @test ShadowGraphs.get_node_list(ring, 10, topo_nodes_broken, 1) == [10,20,30,40]
        @test ShadowGraphs.get_node_list(ring, 40, topo_nodes_broken, 1) == [40,50,60]
        @test ShadowGraphs.get_node_list(ring, 70, topo_nodes_broken, 1) == [70,80,10]

        @test ShadowGraphs.get_node_list(ring, 10, topo_nodes_broken, -1) == [10,80,70]
        @test ShadowGraphs.get_node_list(ring, 40, topo_nodes_broken, -1) == [40,30,20,10]
        @test ShadowGraphs.get_node_list(ring, 70, topo_nodes_broken, -1) == [70,60]

        # start is not part of topology
        topo_nodes_broken = [20,50,60,80]
        @test ShadowGraphs.get_node_list(ring, 20, topo_nodes_broken, 1) == [20,30,40,50]
        @test ShadowGraphs.get_node_list(ring, 60, topo_nodes_broken, 1) == [60,70,80]
        @test ShadowGraphs.get_node_list(ring, 80, topo_nodes_broken, 1) == [80,10,20]

        @test ShadowGraphs.get_node_list(ring, 20, topo_nodes_broken, -1) == [20,10,80]
        @test ShadowGraphs.get_node_list(ring, 60, topo_nodes_broken, -1) == [60,50]
        @test ShadowGraphs.get_node_list(ring, 80, topo_nodes_broken, -1) == [80,70,60]

        @test_throws ArgumentError ShadowGraphs.get_node_list(ring, 20, topo_nodes_broken, 2)  # direction not allowed
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring, 25, topo_nodes_broken, 1)  # start not in way
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring, 40, topo_nodes_broken, 1)  # start not in topo nodes
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring, 10, [10, 45, 50, 90], 1)  # topo nodes not subset of way

        @test_throws ArgumentError ShadowGraphs.get_node_list(Way(2, [10,20,30,40,20,50,10], Dict{String, Any}()), 20, [20, 40, 50], 1)  # non simple way
        @test_throws ArgumentError ShadowGraphs.get_node_list(Way(2, [10,20,30,40,50,20], Dict{String, Any}()), 20, [10, 20, 40], 1)  # non simple way with one duplicate
    end

    @testset "shadow_graph_from_light_osm_graph" begin
        @test false
    end

    @test "get_raw_ways"
    @test "shadow_graph_from_object"
    @test "shadow_graph_from_file"
    @test "shadow_graph_from_download"
end