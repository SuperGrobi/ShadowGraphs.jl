"""

    project_local!(g::T, center_lon=get_prop(g, :center_lon), center_lat=get_prop(g, :center_lat)) where {T<:AbstractMetaGraph}

projects all `ArchGDAL` geometry in the `props` of edges and nodes of `g` to transverse mercator, centered at `center_lon`, `center_lat`
and updates the `:crs` properity of `g` accordingly. All geometry is assumed to be in the `:crs` system. Returns the projected `g`.
"""
function CoolWalksUtils.project_local!(g::T, center_lon=get_prop(g, :center_lon), center_lat=get_prop(g, :center_lat)) where {T<:AbstractMetaGraph}
    projstring = "+proj=tmerc +lon_0=$center_lon +lat_0=$center_lat"
    #println(projstring)
    src = get_prop(g, :crs)
    dest = ArchGDAL.importPROJ4(projstring)
    ArchGDAL.createcoordtrans(trans -> project_graph_edges!(g, trans), src, dest)
    ArchGDAL.createcoordtrans(trans -> project_graph_nodes!(g, trans), src, dest)
    set_prop!(g, :crs, dest)
    return g
end

"""

    project_back!(g::T) where {T<:AbstractMetaGraph}

projects all `ArchGDAL` geometry in the `props` of edges and nodes of `g` back to `EPSG4236` and updates the `:crs` property of `g` accordingly.
Returns `g`.
"""
function CoolWalksUtils.project_back!(g::T) where {T<:AbstractMetaGraph}
    src = get_prop(g, :crs)
    ArchGDAL.createcoordtrans(trans -> project_graph_edges!(g, trans), src, OSM_ref[])
    ArchGDAL.createcoordtrans(trans -> project_graph_nodes!(g, trans), src, OSM_ref[])
    set_prop!(g, :crs, OSM_ref[])
    return g
end

"""

    project_graph_nodes!(g, trans)

applies the `ArchGDAL` transformation `trans` to every `ArchGDAL` geometry in the `props` of the `nodes` of `g`.
"""
function project_graph_nodes!(g, trans)
    for vertex in vertices(g)
        for value in values(props(g, vertex))
            if value isa ArchGDAL.IGeometry
                ArchGDAL.transform!(value, trans)
            end
        end
    end
end

"""

    project_graph_edges!(g, trans)

applies the `ArchGDAL` transformation `trans` to every `ArchGDAL` geometry in the `props` of the `edges` of `g`.
"""
function project_graph_edges!(g, trans)
    for edge in edges(g)
        for value in values(props(g, edge))
            if value isa ArchGDAL.IGeometry
                ArchGDAL.transform!(value::EdgeGeomType, trans)
            end
        end
    end
end