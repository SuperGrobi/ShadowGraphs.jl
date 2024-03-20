# Persistence
## Introduction
Here we collect functions responsible for saving and loading ShadowGraphs to multiple CSV files with fine control
over which properties get saved. This is useful if you want to persist some state of your graph,
for example after adding the shadow intervals, but you are only interested in `:sg_street_length` and `:sg_shadow_length`.

There is a very rudimentary loader returning `DataFrames`, which might be a good starting point to build a graph
from a persisted state as outlined above.

## API

```@index
Pages = ["Persistence.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["Persistence.jl"]
```