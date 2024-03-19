# ShadowGraphs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://SuperGrobi.github.io/ShadowGraphs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://SuperGrobi.github.io/ShadowGraphs.jl/dev/)
[![Build Status](https://github.com/SuperGrobi/ShadowGraphs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SuperGrobi/ShadowGraphs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

this package contains code related to parsing, creating and working with OSM Networks in the context of the CoolWalks project.

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

Since the `MetaDiGraph` type does not support multi-edges, (and plotting of self edges tends to get messed up...) we introduce helper nodes and edges in the following cases:

- if we want to add an edge between distinct nodes where an edge already exists, we add a node to the graph and connect the start and destination nodes to this one.
- if we want to add a self edge, we create two helper nodes and connect these to the start and destination in the appropriate order.

# Check out the documentation for a detailed description of the `MetaDiGraph` produced