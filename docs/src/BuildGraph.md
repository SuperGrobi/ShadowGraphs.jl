# Building Graphs
## Introduction
We use `LightOSM.jl` as a basis to handle all the downloading, saving and importing of OSM data. Therefore, we expose very
functions very similar to the ones in `LightOSM.jl`.

Then, the resulting `LightOSM.OSMGraph` instance is parsed into a `MetaDiGraph`, which is preserves the topology of the original
street network, while reducing the number of nodes as much as possible. The geometry and various other parameters are attached
to the `props` of every edge and vertex.

Even though we only expose a few functions for ease of use, we show all functions here, since it is very important to get an idea
of what exactly this code is doing to your graph, before you start using it in any scientific capacity.

## API

```@index
Pages = ["BuildGraph.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["BuildGraph.jl"]
```