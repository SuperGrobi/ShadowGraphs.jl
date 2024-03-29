```@meta
CurrentModule = ShadowGraphs
```

# ShadowGraphs

Documentation for [ShadowGraphs](https://github.com/SuperGrobi/ShadowGraphs.jl).


# Interface
To be usable in the `MinistryOfCoolWalks` ecosystem, the `shadowgraph::MetaDiGraph` needs to fulfill
a set of requirements detailed below. To check if a graph fulfills the technical requirements use [`ShadowGraphs.check_shadow_graph_integrity`](@ref)

In general, all `props` handled by the `MinistryOfCoolWalks` ecosystem start with `sg_`.
They are considered to be read-only. Setting them directly might lead to unexpected behaviour.

The `weightfield` of the graph should be set to `:sg_street_length`, the `defaultweight` should be `0.0`.

Remember to `ArchGDAL.clone` geometries if you want to use them independently of the graph, otherwise
you might observe strange behaviour when mutating the graph (as you will only get a reference to the geometry from `get_prop(...)`).

## graph level
- `:sg_crs`: Coordinate system the graph is currently in. (Uses `ArchGDAL` coordinate systems.)
- `:sg_offset_dir`: Direction in which the streets should be offset (Should be `+1` for right hand side driving and `-1` for left hand side driving.)
- `:sg_observatory`: `CoolWalksUtils.ShadowObservatory` holding the center of the graph, for projection purposes. (Note that the timezone in the `tz` field is not used.)

## nodes
- `:sg_osm_id`: id of the original node in the OSM database. (set this to anything you want for helper nodes.)
- `:sg_lat`: latitude of the original node in the OSM database.
- `:sg_lon`: longitude of the original node in the OSM database.
- `sg_geometry`: `ArchGDAL` point containing representing the node.
- `:sg_helper`: if this node is a helper node.

## edges
Edges have different properties depending on whether they are helper edges (`:sg_helper`) or not.

If they are helpers, they only have `:sg_helper=true`.

otherwise, the available properties are:
- `:sg_osm_id`: id of the original way in the OSM database.
- `:sg_tags`: tags of the original OSM way. (See [`ShadowGraphs.parse_raw_ways`](@ref) for more information on the content and guarantees.)
- `:sg_geometry_base`: `ArchGDAL linestring` with the geometry of the edge. (Used as baseline to reset the graph.)
- `:sg_street_geometry`: final geometry of the street. (originally a copy of `:sg_geometry_base`, will be modified during offsetting.)
- `:sg_street_length`: length of `sg_street_geometry` in a projected coordinate system.
- `:sg_parsing_direction`: Direction in which we stepped through the original way to get the geometry. (Needed to figure out in which direction the geometry needs to be offset.)
- `:sg_helper=false`: if this edge is a helper edge (always `false` if the above `props` exist.)

# API

```@index
Pages = ["index.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["ShadowGraphs.jl"]
```