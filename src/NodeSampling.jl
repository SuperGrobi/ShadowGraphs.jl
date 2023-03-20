"""

    consolidate_nodes_geom(g, radius)

calculates 
"""
function consolidate_nodes_geom(g, radius)
    project_local!(g, get_prop(g, :center_lon), get_prop(g, :center_lat))
    all_points = ArchGDAL.createmultipoint()
    for v in vertices(g)
        ArchGDAL.addgeom!(all_points, get_prop(g, v, :pointgeom))
    end
    reinterp_crs!(all_points, get_prop(g, :crs))
    println(ngeom(all_points))


    project_back!(g)
    #project_back!([all_points])
    return all_points
end