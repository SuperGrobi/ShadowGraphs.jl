@testitem "plotting from scratch" begin
    using Folium
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    p1 = [1, 785, 446, 1584, 1527, 49, 764, 1375, 115]  # normal edges
    p2 = [1692, 420, 1119, 533, 598, 5, 1632]  # helper nodes at start and end, edge 5 => 1632 is helper edge
    for i in [:vertices, :edges, :streets, :shadows, :sg_street_geometry, p1, p2]
        try
            draw(g, i; figure_params=Dict(:zoom_start => 14))
            @test true
        catch
            @test "error thrown in plotting graph (from scratch) with $i"
        end
    end

    @test_throws ArgumentError draw(g, :nonexistent; color=:red)
end

@testitem "plotting mutations" begin
    using Folium
    cd(@__DIR__)

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    p1 = [1, 785, 446, 1584, 1527, 49, 764, 1375, 115]  # normal edges
    p2 = [1692, 420, 1119, 533, 598, 5, 1632]  # helper nodes at start and end, edge 5 => 1632 is helper edge
    for i in [:vertices, :edges, :streets, :shadows, :sg_street_geometry, p1, p2]
        try
            fig = FoliumMap(zoom_start=14)
            draw!(fig, g, i)
            @test true
        catch
            @test "error thrown in plotting graph (mutating figure) with $i"
        end
    end

    fig = FoliumMap(location=(52.904, -1.18), zoom_start=14)
    @test_throws ArgumentError draw!(fig, g, :nonexistent; color=:red)
end