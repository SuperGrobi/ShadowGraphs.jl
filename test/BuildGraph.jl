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


    @testset "get_neighbor_osm_ids lines" begin
        # get_neighbor_osm_ids
        line1 = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line1"))
        line2 = Way(2, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>false, "name"=>"line2"))
        line3 = Way(3, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>true, "name"=>"line3"))

        nodes_in_nav_graph = [10, 40, 50, 70]

        # line 1
        @test ShadowGraphs.get_neighbor_osm_ids(line1, 1, nodes_in_nav_graph) == ([40], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(line1, 2, nodes_in_nav_graph) == ([10, 50], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(line1, 3, nodes_in_nav_graph) == ([40, 70], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(line1, 4, nodes_in_nav_graph) == ([50], [-1])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(line1, 1, [10, 40, 55, 70])

        # line 2
        @test ShadowGraphs.get_neighbor_osm_ids(line2, 1, nodes_in_nav_graph) == ([40], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(line2, 2, nodes_in_nav_graph) == ([50], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(line2, 3, nodes_in_nav_graph) == ([70], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(line2, 4, nodes_in_nav_graph) == ([], [])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(line2, 3, [10, 40, 55, 70])

        # line 3
        @test ShadowGraphs.get_neighbor_osm_ids(line3, 1, nodes_in_nav_graph) == ([], [])
        @test ShadowGraphs.get_neighbor_osm_ids(line3, 2, nodes_in_nav_graph) == ([10], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(line3, 3, nodes_in_nav_graph) == ([40], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(line3, 4, nodes_in_nav_graph) == ([50], [-1])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(line3, 3, [10, 40, 55, 70])
    end

    @testset "get_neighbor_osm_ids rings with duplicate in nav" begin
        ring1 = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring1"))
        ring2 = Way(2, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>false, "name"=>"ring2"))
        ring3 = Way(3, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>true, "name"=>"ring3"))
        
        nodes_in_nav_graph = [10, 30, 60, 70]

        #ring 1
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 1, nodes_in_nav_graph) == ([70, 30], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 2, nodes_in_nav_graph) == ([10, 60], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 3, nodes_in_nav_graph) == ([30, 70], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 4, nodes_in_nav_graph) == ([60, 10], [-1, 1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring1, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring1, 0, [10, 30, 70, 10])

        # ring 2
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 1, nodes_in_nav_graph) == ([30], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 2, nodes_in_nav_graph) == ([60], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 3, nodes_in_nav_graph) == ([70], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 4, nodes_in_nav_graph) == ([10], [1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring2, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring2, 2, [10, 40, 60, 10])

        # ring 3
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 1, nodes_in_nav_graph) == ([70], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 2, nodes_in_nav_graph) == ([10], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 3, nodes_in_nav_graph) == ([30], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 4, nodes_in_nav_graph) == ([60], [-1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring3, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring3, 2, [10, 40, 60, 10])
    end

    @testset "get_neighbor_osm_ids rings without duplicate in nav" begin
        ring1 = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring1"))
        ring2 = Way(2, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>false, "name"=>"ring2"))
        ring3 = Way(3, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>true, "reverseway"=>true, "name"=>"ring3"))
        
        nodes_in_nav_graph = [20, 40, 60, 70]

        #ring 1
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 1, nodes_in_nav_graph) == ([70, 40], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 2, nodes_in_nav_graph) == ([20, 60], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 3, nodes_in_nav_graph) == ([40, 70], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring1, 4, nodes_in_nav_graph) == ([60, 20], [-1, 1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring1, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring1, 0, [10, 30, 70, 10])

        # ring 2
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 1, nodes_in_nav_graph) == ([40], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 2, nodes_in_nav_graph) == ([60], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 3, nodes_in_nav_graph) == ([70], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring2, 4, nodes_in_nav_graph) == ([20], [1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring2, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring2, 2, [10, 40, 60, 10])

        # ring 3
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 1, nodes_in_nav_graph) == ([70], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 2, nodes_in_nav_graph) == ([20], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 3, nodes_in_nav_graph) == ([40], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(ring3, 4, nodes_in_nav_graph) == ([60], [-1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring3, 0, [10, 40, 55, 70])
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(ring3, 2, [10, 40, 60, 10])
    end

    @testset "get_neighbor_osm_ids lolipops" begin
        loli1 = Way(1, [10,20,30,40,50,60,70, 30], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli1"))
        loli2 = Way(2, [10,20,30,40,50,60,70, 30], Dict("oneway"=>true, "reverseway"=>false, "name"=>"loli2"))
        loli3 = Way(3, [10,20,30,40,50,60,70, 30], Dict("oneway"=>true, "reverseway"=>true, "name"=>"loli3"))

        nodes_in_nav_graph = [10, 30, 60, 30]

        #loli1
        @test ShadowGraphs.get_neighbor_osm_ids(loli1, 1, nodes_in_nav_graph) == ([30], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli1, 2, nodes_in_nav_graph) == ([10, 60], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli1, 3, nodes_in_nav_graph) == ([30, 30], [-1, 1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli1, 4, nodes_in_nav_graph) == ([60], [-1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli1, 0, nodes_in_nav_graph)
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli1, 2, [10, 25, 30, 25])

        #loli2
        @test ShadowGraphs.get_neighbor_osm_ids(loli2, 1, nodes_in_nav_graph) == ([30], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli2, 2, nodes_in_nav_graph) == ([60], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli2, 3, nodes_in_nav_graph) == ([30], [1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli2, 4, nodes_in_nav_graph) == ([], [])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli2, 0, nodes_in_nav_graph)
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli2, 2, [10, 25, 30, 25])

        #loli3
        @test ShadowGraphs.get_neighbor_osm_ids(loli3, 1, nodes_in_nav_graph) == ([], [])
        @test ShadowGraphs.get_neighbor_osm_ids(loli3, 2, nodes_in_nav_graph) == ([10], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli3, 3, nodes_in_nav_graph) == ([30], [-1])
        @test ShadowGraphs.get_neighbor_osm_ids(loli3, 4, nodes_in_nav_graph) == ([60], [-1])

        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli3, 0, nodes_in_nav_graph)
        @test_throws ArgumentError ShadowGraphs.get_neighbor_osm_ids(loli3, 2, [10, 25, 30, 25])
    end

    @testset "is_lolipop_node" begin
        osm_g = graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
        @test ShadowGraphs.is_lolipop_node(osm_g, 323231794)
        @test ShadowGraphs.is_lolipop_node(osm_g, 322852698)
        @test ShadowGraphs.is_lolipop_node(osm_g, 322837719)
        @test !ShadowGraphs.is_lolipop_node(osm_g, 323204711)
        @test !ShadowGraphs.is_lolipop_node(osm_g, 2307602759)
        @test !ShadowGraphs.is_lolipop_node(osm_g, 323204751)
        @test !ShadowGraphs.is_lolipop_node(osm_g, 26955809)
        @test !ShadowGraphs.is_lolipop_node(osm_g, 3726792252)
    end

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
end

osm_g = graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)


line1 = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line1"))
line2 = Way(2, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>false, "name"=>"line2"))
line3 = Way(3, [10,20,30,40,50,60,70,80], Dict("oneway"=>true, "reverseway"=>true, "name"=>"line3"))

ShadowGraphs.get_node_list(line1, 9, 60, -1)

ring1 = Way(1, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring1"))
ShadowGraphs.get_node_list(ring1, 9, 10, -1)
