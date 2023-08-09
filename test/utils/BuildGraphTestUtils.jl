function setup_testgraph()
    es = [(2, 4), (3, 4), (4, 1), (4, 3), (4, 6), (5, 4), (5, 6), (6, 4)]
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
        set_prop!(g, n, :sg_lon, lons[n])
        set_prop!(g, n, :sg_lat, lats[n])
    end
    add_vertex!(g)
    return g
end