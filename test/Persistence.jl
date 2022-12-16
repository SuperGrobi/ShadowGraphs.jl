@testset "Persistence" begin
    rm("./tmp", recursive=true, force=true)
    mkdir("./tmp")
    
    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    export_graph_to_csv("./tmp/full.csv", g)
    export_graph_to_csv("./tmp/reduced.csv", g; remove_internal_data=true)

    created_files = readdir("./tmp")
    @test "full_edges.csv" in created_files
    @test "full_nodes.csv" in created_files
    @test "full_graph.csv" in created_files
    @test "reduced_edges.csv" in created_files
    @test "reduced_nodes.csv" in created_files
    @test "reduced_graph.csv" in created_files

    @test countlines("./tmp/full_edges.csv") == ne(g)+1
    @test countlines("./tmp/full_nodes.csv") == nv(g)+1
    @test countlines("./tmp/full_graph.csv") == 2

    @test countlines("./tmp/reduced_edges.csv") == ne(g)+1
    @test countlines("./tmp/reduced_nodes.csv") == nv(g)+1
    @test countlines("./tmp/reduced_graph.csv") == 2

    @test filesize("./tmp/full_edges.csv") > filesize("./tmp/reduced_edges.csv")
    @test filesize("./tmp/full_nodes.csv") > filesize("./tmp/reduced_nodes.csv")
    @test filesize("./tmp/full_graph.csv") == filesize("./tmp/reduced_graph.csv")

    @test_throws ArgumentError import_graph_from_csv("./tmp/reduced.csv")

    g_loaded = import_graph_from_csv("./tmp/full.csv")
    @test nv(g_loaded) == nv(g)
    @test ne(g_loaded) == ne(g)
    try
        project_local!(g_loaded, -1, 53)
        @test true
    catch e
        @test false
        rethrow(e)
    end
    
    rm("./tmp", recursive=true)
end