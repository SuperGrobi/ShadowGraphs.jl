# Graph Measures
## Introduction
We reimplement some measures for spatial graphs presented in
[OSMnx](https://github.com/gboeing/osmnx) to work on the shadow graphs described
in this package.

For now, only bearing and orientation entropy are available.
See [Boeing, G. 2019. “Urban Spatial Order: Street Network Orientation, Configuration, and Entropy.” Applied Network Science, 4 (1), 67](https://doi.org/10.1007/s41109-019-0189-1)
for the technical details.

Whenever a measurment attaches data to the graph, the tag will be prefixed with
`ms_`, generally we do not checked if the tag exists before overwriting it.
Modifying the graph will cause the measures depending on the modified part to go
out of sync.

## API

```@index
Pages = ["Measures.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["Measures.jl"]
```