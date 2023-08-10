@testitem "Persistence" begin
    using DataFrames, Graphs
    cd(@__DIR__)

    rm("./tmp", recursive=true, force=true)
    mkdir("./tmp")

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    export_shadow_graph_to_csv("./tmp/full.csv", g)
    export_shadow_graph_to_csv("./tmp/reduced.csv", g; edge_props=[:sg_street_geometry, :sg_helper], vertex_props=Not([:sg_helper, :sg_geometry]))

    created_files = readdir("./tmp")
    @test "full_edges.csv" in created_files
    @test "full_nodes.csv" in created_files
    @test "full_graph.csv" in created_files
    @test "reduced_edges.csv" in created_files
    @test "reduced_nodes.csv" in created_files
    @test "reduced_graph.csv" in created_files

    @test countlines("./tmp/full_edges.csv") == ne(g) + 1
    @test countlines("./tmp/full_nodes.csv") == nv(g) + 1
    @test countlines("./tmp/full_graph.csv") == 2

    @test countlines("./tmp/reduced_edges.csv") == ne(g) + 1
    @test countlines("./tmp/reduced_nodes.csv") == nv(g) + 1
    @test countlines("./tmp/reduced_graph.csv") == 2

    @test filesize("./tmp/full_edges.csv") > filesize("./tmp/reduced_edges.csv")
    @test filesize("./tmp/full_nodes.csv") > filesize("./tmp/reduced_nodes.csv")
    @test filesize("./tmp/full_graph.csv") == filesize("./tmp/reduced_graph.csv")

    edf, vdf, gdf = import_shadow_graph_from_csv("./tmp/full.csv")
    @test nrow(vdf) == nv(g)
    @test nrow(edf) == ne(g)

    @test "sg_street_length" in names(edf)
    @test "sg_street_geometry" in names(edf)

    @test "sg_geometry" in names(vdf)
    @test "sg_lon" in names(vdf)

    edf, vdf, gdf = import_shadow_graph_from_csv("./tmp/reduced.csv")
    @test nrow(vdf) == nv(g)
    @test nrow(edf) == ne(g)

    @test !("sg_street_length" in names(edf))
    @test "sg_street_geometry" in names(edf)

    @test !("sg_geometry" in names(vdf))
    @test "sg_lon" in names(vdf)


    rm("./tmp", recursive=true)
end