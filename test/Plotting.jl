@testset "plotting" begin
    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

    for i in [:vertices, :edges, :edgegeom, :shadowgeom]
        try
            draw(g, i; figure_params=Dict(:location=>(52.904, -1.18), :zoom_start=>14))
            @test true
        catch
            @test "error thrown in plotting graph (from scratch) with $i"
        end
    end

    @test_throws ArgumentError draw(g, :nonexistent; color=:red)

    for i in [:vertices, :edges, :edgegeom, :shadowgeom]
        try
            fig = FoliumMap(location= (52.904, -1.18), zoom_start= 14)
            draw!(fig, g, i)
            @test true
        catch
            @test "error thrown in plotting graph (mutating figure) with $i"
        end
    end

    fig = FoliumMap(location= (52.904, -1.18), zoom_start= 14)
    @test_throws ArgumentError draw!(fig, g, :nonexistent; color=:red)
end