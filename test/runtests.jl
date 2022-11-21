using ShadowGraphs
using LightOSM
using Test

@testset "Circularity weirdness" begin
    @test true
    tags = Dict{String, Any}("oneway"=>false)
    roundabout_start_end = Way(1, [1,2,3,4,5,6,7,8,1], tags)
    roundabout_non_start = Way(1, [8,1,2,3,4,5,6,7,8], tags)
    selfloop_start = Way(1, [1,2,3,4,1], tags)
    selfloop_non_start = Way(1, [4,1,2,3,4], tags)
    
    for start_index in [1,2,3,4]
        neighs = ShadowGraphs.get_neighbor_indices(roundabout_start_end, start_index, [1,3,5,7])
        println(neighs)
    end
    println("")
    for start_index in [1,2,3,4]
        neighs = ShadowGraphs.get_neighbor_indices(roundabout_non_start, start_index, [1,3,5,7])
        println(neighs)
    end
    println("")
    for start_index in [1]
        neighs = ShadowGraphs.get_neighbor_indices(selfloop_start, start_index, [1])
        println(neighs)
    end
    println("")
    for start_index in [1]
        neighs = ShadowGraphs.get_neighbor_indices(selfloop_start, start_index, [1])
        println(neighs)
    end
    println("")
    lolipop = Way(1, [9,2,3,4,5,6,3], tags)
    neighs = ShadowGraphs.get_neighbor_indices(lolipop, 1, [9])
    println(neighs)
end