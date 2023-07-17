# ShadowGraphs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://SuperGrobi.github.io/ShadowGraphs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://SuperGrobi.github.io/ShadowGraphs.jl/dev/)
[![Build Status](https://github.com/SuperGrobi/ShadowGraphs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SuperGrobi/ShadowGraphs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

this package will contain (contains) code related to parsing, creating and working with OSM Networks in the context of the CoolWalks project.

# WARNING: At the moment, all the things in here are probably... 70% correct.
This needs some cleanup. Whenever you read something here and it does not seem to be right... It probably isn't. I am to blame. It is not you.

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

The Graph has two props itself:
- `:csr` This contains some kind of crs information. Not sure if I am actually going to use it...
- `:offset_dir` either 1 or -1. Whether we need to move the line to the left (-1, greater british empire) or to the right (1, everywhere else in the world)

In general, for non-helper nodes and edges, the following props are available:

- Nodes
    - `:osm_id` (osm id of vertex)
    - `:lat`
    - `:lon`
    - `:pointgeom` (GDAL point representing the location of nodes)
    - `:helper` if this node is a helper node.

- Edges
    - `:osm_id` (osm id of way which connects the start and end)
    - `:edgegeom` (ArchGDAL Linestring with coordinates of the nodes in the Way connecting the start and end, in WSG84)
    - `:geomlength` (geometric length of street between start and end. (currently always 0 directly after initialisation. Is set elsewhere.)
    - `:helper` if this edge is a helper edge
    - `:tags` dictionary of tags extracted from the original way. We guarante the existence of the following tags:
        - `oneway` (whether the way can only be used in one direction)
        - `reverseway` (if direction in which the way can be accessed (in terms of road usage) is the oposite of the direction in which it is mapped)
        - `width` (width of the street. `missing` if none is mapped)
        - `lanes` (total number of lanes on this street. `missing` if none is mapped)
        - `lanes:forward` (number of lanes in mapped direction of way (this convention leaves this tag independent of the `reverseway` tag.) `missing` if none is mapped)
        - `lanes:backward` (number of lanes against mapped direction of way. `missing` if none is mapped)
        - `maxspeed` (maximal allowed speed on this road. uses some default values defined in `LightOSM.jl` (we don't realy care about this property.))
    - `parsing_direction` either -1 or 1, denotes the direction in which we had to step through the original way to get from the source to the destination. (using this, we can see wether we need to use the `lanes:forward` or the `lanes:backward` tag... 1 means forward, -1 means backward)


Helper nodes and edges have the following `props`:
- Nodes
    - `:lat`
    - `:lon`
    - `:pointgeom` (GDAL point representing the location of nodes)
    - `:helper` if this node is a helper node

- Edges
    - `:helper` if this is a helper edge


That should be it. The code is very messy and badly commented. If you have any questions just shout although I probably will not be able to remember why I did stuff the way I did it. (It works... I think.)

Note to self: I should add tests. (Note to everybody else: If you want to write tests... you are more than welcome to do so.)
