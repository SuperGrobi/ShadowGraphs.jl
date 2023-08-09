# Projecting Shadow Graphs
## Introduction
We add methods to `project_local!` and `project_back!` from [`CoolWalksUtils.jl`](https://github.com/SuperGrobi/CoolWalksUtils.jl) which allow for simpler projection of shadow graphs. Whithin them, the `ArchGDAL` geometry attached to nodes and edges are projected into a transverse mercator projection, and back.


## API

```@index
Pages = ["Projection.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["Projection.jl"]
```