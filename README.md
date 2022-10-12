# ShadowGraphs

this package will contain (contains) code related to parsing, creating and working with OSM Networks in the context of the CoolWalks project.

## User Interface
Currently, there are three user facing methods for loading/importing/parsing data to a shadow graph (currently a MetaDiGraph instance):

- `shadow_graph_from_object` this one creates the shadow graph from the stuff that is returned by calling the `LightOSM.jl` provided `download_osm_network` function. (Either a Dict or a LightXML thingy)
- `shadow_graph_from_file` well...same as above, but with a filepath
- `shadow_graph_from_download` again... same, but downloads the graph first.

The syntax for these functions mainly follows the `LightOSM.jl` counterparts. For now, look there for Documentation on the available methods.

## The Shadow Graph
The shadow graph is an instance of a `MetaDiGraph` object. During creation, we build the LightOSM graph, which then informs the content of the shadow graph.

The main distinction between the `OSMGraph` and the shadow graph is, that we
1. keep only nodes at the ends of ways and those who are relevant for the topology of the graph
2. attach all relevant data as `props` to  the edges and nodes.

Since the `MetaDiGraph` type does not support multi-edges, (and plotting of self edges tends to get messed up...) we currently introduce helper nodes and edges in the following cases:

- if we want to add an edge between distinct nodes where an edge already exists, we add a node to the graph and connect the start and destination nodes to this one.
- if we want to add a self edge, we create two helper nodes and connect these to the start and destination in the appropriate order.

In general, for non-helper nodes and edges, the following props are available:

- Nodes
    - `:osm_id` (osm id of vertex)
    - `:lat`
    - `:lon`
    - `:end` (if this vertex is the end of a way (might remove this in the future))
    - `:geopoint` (ArchGDAL Point with lat and lon in WSG84)

- Edges
    - `:osm_id` (osm id of way which connects the start and end)
    - `:edgegeom` (ArchGDAL Linestring with coordinates of the nodes in the Way connecting the start and end, in WSG84)
    - `:geomlength` (geometric length of street between start and end. (currently always 0, since I did not yet implement this...))

Be aware, that helper edges and nodes do not have all of these properties. Before getting these props a check if they exist is in order. Else stuff breaks. Helper nodes and edges have the following `props`:
- Nodes
    - `:osm_id` (always 0)
    - `:lat`
    - `:lon`
    - `:end` (always false) (will probably get removed at some point)
    - `:helper` (always true)

(I will add the `:geopoint` at some point.)

- Edges
    - `:helper` (always true)

I should probably overhaul all of this at some point in the future.

That should be it. The code is very messy and badly commented. If you have any questions just shout although I probably will not be able to remember why I did stuff the way I did it. (It works... I think.)

Note to self: I should add tests. (If you want to write tests... you are the most welcome to do so.)