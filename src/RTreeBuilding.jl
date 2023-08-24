"""
    CoolWalksUtils.build_rtree(g::AbstractMetaGraph)

builds `SpatialIndexing.RTree{Float64, 2}` from an `AbstractMetaGraph` containing vertices with at least a `:sg_geometry` prop and edges with a `:sg_street_geometry` prop.
(edges and vertices without this prop are skipped, but do not throw an error.) The extent of each node is based on these properties.

The `id` of each entry in the tree is of type `Edge` and represents the edge the values are derived from. If the entry is a vertex `v`, the `id` will be an `Edge(v,v)`.
(See also the `val.type` entry on how to distiguish between edges and nodes.)

The value of an entry in the RTree is a named tuple with: `(orig=original_geometry, prep=prepared_geometry, type=graph_geom_type, data=props_of_edge_or_vertex)`.
where `orig` is the original geometry stored in `props[:sg_geometry]` or `props[:sg_street_geometry]`, and `prep` is the prepared geometry, derived from `orig`.
It can be used in a few `ArchGDAL` functions to get higher performance, for example in intersection testing, because relevant values get precomputed and
cashed in the prepared geometry, rather than recomputed on every test.

Note that only the first element in these tests can be a prepared geometry, for example `ArchGDAL.intersects(normal_geom, prepared_geom)`
is a highway to segfault-town, while `ArchGDAL.intersects(prepared_geom, normal_geom)` is fine and great.

The `type` entry is either `:edge` or `:vertex`, to help distinguish between entries for edges and vertices.

The `data` entry contains the Dictionary returned by `props(g, i)` where i is either a vertex or an edge. This gives access to all relevant properties of the graph.
"""
function CoolWalksUtils.build_rtree(g::AbstractMetaGraph)
    rt = RTree{Float64,2}(Edge, NamedTuple{(:orig, :prep, :type, :data),Tuple{ArchGDAL.IGeometry,ArchGDAL.IPreparedGeometry,Symbol,Dict{Symbol,Any}}})
    for v in filter_vertices(g, :sg_geometry)
        geom = get_prop(g, v, :sg_geometry)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, Edge(v, v), (orig=geom, prep=ArchGDAL.preparegeom(geom), type=:vertex, data=props(g, v)))
    end
    for e in filter_edges(g, :sg_street_geometry)
        geom = get_prop(g, e, :sg_street_geometry)
        bbox = rect_from_geom(geom)
        insert!(rt, bbox, e, (orig=geom, prep=ArchGDAL.preparegeom(geom), type=:edge, data=props(g, e)))
    end
    return rt
end