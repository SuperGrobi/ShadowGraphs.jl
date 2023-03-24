# Node Sampling
## Introduction
I guess the title is a bit ill-choosen for what it actually is. These functions are used to distance-merge nodes in the already simplified graph. This functionality is heavily inspired by the `consolidate_intersections` function in `osmnx`, but heavily specified for our usecase and, arguably, a lot faster and a bit more realistic.

The general motivation for these functions was to be able to keep the street level complexity of our network, while at the same time beeing able to approximate all to all demand a lot faster, by essentially only routing from one node for each highly dense cluster.

The other motivation was, that the high node density around intersections over represents these areas in our quest for something akin to a spatially homogenous all to all demand. Therefore, we also return the total length of all inbound streets into our consolidated cluster.

## API

```@index
Pages = ["NodeSampling.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["NodeSampling.jl"]
```