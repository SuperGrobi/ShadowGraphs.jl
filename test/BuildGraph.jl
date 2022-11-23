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

@testset "Graph loading" begin
    # is_end_node
    g = setup_testgraph()
    solutions = [true, true, true, false, false, false]
    for (node, solution) in zip(vertices(g), solutions)
        @test ShadowGraphs.is_end_node(g, node) == solution
    end

    # point_on_radius
    x = [40.5, -21.3, 7.6]
    y = [15.12, 9.0, -30.6]
    r = [0.045, 7.6, 0.00012]
    for i in zip(x, y, r)
        xp, yp = ShadowGraphs.point_on_radius(i...)
        for (x2, y2) in zip(xp, yp)
            r2 = sqrt((i[1] - x2)^2 + (i[2] - y2)^2)
            @test r2 ≈ i[3]
        end
    end

    # offset_point_between
    g = MetaDiGraph(3)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 1, 3)
    set_prop!(g, 1, :lon, 5.4)
    set_prop!(g, 1, :lat, 10.3)
    set_prop!(g, 2, :lon, 5.9)
    set_prop!(g, 2, :lat, -4.3)

    x, y = ShadowGraphs.offset_point_between(g, 1, 2)
    @test sqrt((x-5.4)^2 + (y-10.3)^2) ≈ sqrt((x-5.9)^2 + (y - -4.3)^2) 
    @test_throws KeyError ShadowGraphs.offset_point_between(g, 1, 3)

    # add_edge_with_data
    data = Dict(:a => 1, :b => 2)

    g = setup_addingraph()
    # simple edge
    ShadowGraphs.add_edge_with_data!(g, 1, 3, data=data)
    @test has_edge(g, 1, 3)
    @test !has_edge(g, 3, 1)
    @test get_prop(g, 1, 3, :a) == 1
    @test get_prop(g, 1, 3, :b) == 2
    @test ne(g) == 1

    # simple edge
    ShadowGraphs.add_edge_with_data!(g, 3, 4, data=data)
    @test has_edge(g, 3, 4)
    @test !has_edge(g, 4, 3)
    @test get_prop(g, 3, 4, :a) == 1
    @test get_prop(g, 3, 4, :b) == 2
    @test ne(g) == 2

    # multi edge
    ShadowGraphs.add_edge_with_data!(g, 1, 3, data=data)
    @test ne(g) == 4
    @test has_vertex(g, 6)
    @test has_edge(g, 1, 6)
    @test has_edge(g, 6, 3)

    @test get_prop(g, 6, :helper)
    @test get_prop(g, 1, 6, :helper)
    @test get_prop(g, 6, 3, :a) == 1
    @test get_prop(g, 6, 3, :b) == 2

    # self edge
    ShadowGraphs.add_edge_with_data!(g, 2, 2, data=data)
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
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 3, data=data)
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 3, 5, data=data)
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 5, 5, data=data)
    add_edge!(g, 4, 5)
    @test_throws KeyError ShadowGraphs.add_edge_with_data!(g, 4, 5, data=data)

    # is_circular_way
    w1 = Way(1, [1,2,3,4,5,6,1], Dict("oneway"=>true, "isroundabout"=>true, "name" => "testroundabout"))
    w2 = Way(2, [7,8,9,10,11], Dict("oneway"=>false, "isroundabout"=>false, "highway" => "residential"))
    @test ShadowGraphs.is_circular_way(w1)
    @test !ShadowGraphs.is_circular_way(w2)


    @testset "get_node_list lines" begin
        line1 = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line1"))
        line2 = Way(2, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>false, "name"=>"line2"))
        line3 = Way(3, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>true, "name"=>"line3"))

        @test ShadowGraphs.get_node_list(line1, 2, 60, 1) == [20, 30, 40, 50, 60]
        @test ShadowGraphs.get_node_list(line1, 5, 80, 1) == [50 ,60, 70, 80]
        @test_throws ArgumentError ShadowGraphs.get_node_list(line1, 2, 60, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line1, 6, 20, 1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line1, 2, 65, -1)
        @test_throws BoundsError ShadowGraphs.get_node_list(line1, 12, 60, -1)

        @test ShadowGraphs.get_node_list(line2, 2, 60, 1) == [20, 30, 40, 50, 60]
        @test ShadowGraphs.get_node_list(line2, 5, 80, 1) == [50 ,60, 70, 80]
        @test_throws ArgumentError ShadowGraphs.get_node_list(line2, 2, 60, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line2, 6, 20, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line2, 6, 20, 1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line2, 2, 65, 1)

        @test ShadowGraphs.get_node_list(line3, 6, 20, -1) == [60, 50, 40, 30, 20]
        @test ShadowGraphs.get_node_list(line3, 8, 50, -1) == [80, 70, 60, 50]
        @test_throws ArgumentError ShadowGraphs.get_node_list(line3, 2, 60, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line3, 6, 20, 1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(line3, 2, 65, 1)
        
    end

    @testset "get_node_list rings" begin
        ring1 = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring1"))
        ring2 = Way(2, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>false, "name"=>"ring2"))
        ring3 = Way(3, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>true, "name"=>"ring3"))

        @test ShadowGraphs.get_node_list(ring1, 2, 80, 1) == [20, 30, 40, 50, 60, 70, 80]
        @test ShadowGraphs.get_node_list(ring1, 2, 80, -1) == [20, 10, 80]
        @test ShadowGraphs.get_node_list(ring1, 1, 10, -1) == [10, 10]
        @test ShadowGraphs.get_node_list(ring1, 7, 20, 1) == [70, 80, 10, 20]
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring1, 2, 65, 1)
        @test_throws BoundsError ShadowGraphs.get_node_list(ring1, 12, 60, -1)

        @test ShadowGraphs.get_node_list(ring2, 2, 80, 1) == [20, 30, 40, 50, 60, 70, 80]
        @test ShadowGraphs.get_node_list(ring2, 7, 20, 1) == [70, 80, 10, 20]
        @test ShadowGraphs.get_node_list(ring2, 1, 10, 1) == [10,20,30,40,50,60,70,80,10]
        @test ShadowGraphs.get_node_list(ring2, 9, 10, 1) == [10,10]

        @test_throws ArgumentError ShadowGraphs.get_node_list(ring2, 1, 10, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring2, 2, 80, -1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring2, 2, 65, 1)
        @test_throws BoundsError ShadowGraphs.get_node_list(ring2, 12, 60, 1)

        @test ShadowGraphs.get_node_list(ring3, 2, 80, -1) == [20, 10, 80]
        @test ShadowGraphs.get_node_list(ring3, 7, 20, -1) == [70, 60, 50, 40, 30, 20]
        @test ShadowGraphs.get_node_list(ring3, 1, 10, -1) == [10, 10]
        @test ShadowGraphs.get_node_list(ring3, 9, 10, -1) == [10, 80, 70, 60,50, 40, 30, 20, 10]

        @test_throws ArgumentError ShadowGraphs.get_node_list(ring3, 1, 10, 1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring3, 2, 80, 1)
        @test_throws ArgumentError ShadowGraphs.get_node_list(ring3, 2, 65, 1)
        @test_throws BoundsError ShadowGraphs.get_node_list(ring3, 12, 60, -1)
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
end