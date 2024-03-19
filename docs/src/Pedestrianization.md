# Pedestrianization

## Introduction
Our shadow graphs are generally directed to allow for one-way streets. However,
in the context of pedestrian routing, we might want to ignore this directedness.
When *pedestrianizing* a graph, we add the reverse edge for every edge if it
does not yet exist, together with the correctly inverted data like geometry and
parsing direction.

Apply before centerline correction, as the revese edge should be offset in the
other direction.


## API

```@index
Pages = ["Pedestrianization.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["Pedestrianization.jl"]
```