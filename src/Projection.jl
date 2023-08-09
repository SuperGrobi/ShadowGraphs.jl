"""

    project_local!(g::T, obs::ShadowObservatory=get_prop(g, :sg_observatory)) where {T<:AbstractMetaGraph}
    project_local!(g::T, lon, lat) where {T<:AbstractMetaGraph}

projects all `ArchGDAL` geometry in the `props` of edges and nodes of `g` to transverse mercator, centered around the `obs` (or `lon`, `lat`)
and updates the `:sg_crs` property of `g` accordingly. All geometry is assumed to be in the `:sg_crs` system. Returns the projected `g`.
"""
CoolWalksUtils.project_local!(g::T, obs::ShadowObservatory=get_prop(g, :sg_observatory)) where {T<:AbstractMetaGraph} = project_local!(g, obs.lon, obs.lat)
function CoolWalksUtils.project_local!(g::T, lon, lat) where {T<:AbstractMetaGraph}
    src = get_prop(g, :sg_crs)
    dst = CoolWalksUtils.crs_local(lon, lat)
    ArchGDAL.createcoordtrans(trans -> _execute_edge_projection!(g, trans), src, dst)
    ArchGDAL.createcoordtrans(trans -> _execute_node_projection!(g, trans), src, dst)
    set_prop!(g, :sg_crs, dst)
    return g
end

"""
    project_back!(g::T) where {T<:AbstractMetaGraph}

projects all `ArchGDAL` geometry in the `props` of edges and nodes of `g` back to `EPSG4236` and updates the `:sg_crs` property of `g` accordingly.
Returns `g`.
"""
function CoolWalksUtils.project_back!(g::T) where {T<:AbstractMetaGraph}
    src = get_prop(g, :sg_crs)
    ArchGDAL.createcoordtrans(trans -> _execute_edge_projection!(g, trans), src, OSM_ref[])
    ArchGDAL.createcoordtrans(trans -> _execute_node_projection!(g, trans), src, OSM_ref[])
    set_prop!(g, :sg_crs, OSM_ref[])
    return g
end

"""
    _execute_node_projection!(g, trans)

applies the `ArchGDAL` transformation `trans` to every `ArchGDAL` geometry in the `props` of the `nodes` of `g`.
"""
function _execute_node_projection!(g, trans)
    for vertex in vertices(g)
        for value in values(props(g, vertex))
            if value isa ArchGDAL.IGeometry
                ArchGDAL.transform!(value, trans)
            end
        end
    end
end

"""
    _execute_edge_projection!(g, trans)

applies the `ArchGDAL` transformation `trans` to every `ArchGDAL` geometry in the `props` of the `edges` of `g`.
"""
function _execute_edge_projection!(g, trans)
    for edge in edges(g)
        for value in values(props(g, edge))
            if value isa ArchGDAL.IGeometry
                ArchGDAL.transform!(value::EdgeGeomType, trans)
            end
        end
    end
end