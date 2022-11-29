@testset "Projection" begin
    g = MetaDiGraph()

    @test_throws KeyError project_local!(g, 1.0, 2.0)  # no crs set
    set_prop!(g, :crs, OSM_ref[])

    project_local!(g, 1.0, 2.0)
    @test contains(repr(get_prop(g, :crs)), "proj=tmerc")
    project_back!(g)
    @test repr(get_prop(g, :crs)) == repr(OSM_ref[])
    
    add_vertex!(g, Dict(:a=>ArchGDAL.createpoint(1.0, 2.0), :b=>"test"))
    add_vertex!(g, Dict(:pointgeom=>ArchGDAL.createpoint(5.0, 9.0), :tuple=>(1,2)))
    add_vertex!(g, Dict(:pointgeom=>ArchGDAL.createpoint(5.0, 9.0), :list=>[1,3]))

    add_edge!(g, 1, 2, Dict(:line=>ArchGDAL.createlinestring([1.0, 3.0, 5.0], [2.0, 7.3, 9.0]), :name=>"name"))
    add_edge!(g, 1, 3, Dict(:name=>"nonstreet", :length=>12.5))

    project_local!(g, 1.0, 2.0)
    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 0
    @test get_prop(g, 1, :b) == "test"
    @test !(ArchGDAL.getx(get_prop(g, 2, :pointgeom), 0) ≈ 5.0)
    @test !(ArchGDAL.gety(get_prop(g, 2, :pointgeom), 0) ≈ 9.0)
    @test get_prop(g, 2, :tuple) == (1,2)
    @test get_prop(g, 3, :list) == [1,3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) > 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test contains(repr(get_prop(g, :crs)), "proj=tmerc")

    project_back!(g)

    @test ArchGDAL.getx(get_prop(g, 1, :a), 0) ≈ 1.0
    @test ArchGDAL.gety(get_prop(g, 1, :a), 0) ≈ 2.0
    @test get_prop(g, 1, :b) == "test"
    @test ArchGDAL.getx(get_prop(g, 2, :pointgeom), 0) ≈ 5.0
    @test ArchGDAL.gety(get_prop(g, 2, :pointgeom), 0) ≈ 9.0
    @test get_prop(g, 2, :tuple) == (1,2)
    @test get_prop(g, 3, :list) == [1,3]

    @test ArchGDAL.geomlength(get_prop(g, 1, 2, :line)) < 11
    @test get_prop(g, 1, 3, :length) ≈ 12.5

    @test repr(get_prop(g, :crs)) == repr(OSM_ref[])
end