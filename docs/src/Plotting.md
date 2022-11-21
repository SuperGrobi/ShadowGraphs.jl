# Plotting
## Introduction
We extend the functionality of (`Folium.jl`)[https://github.com/SuperGrobi/Folium.jl] to be quickly able to visualise the shadowgraph in an interactive `Leaflet.js` map.

As most alternative packages in julia are quiet slow with regards to the drawing of very large graphs, this is currently the only way of getting close to interactive maps.

TODO:
- maybe vectorise the inputs to set values "per edge"/ "per node" (`GraphRecipes.jl`?)
- use/find alternative options to plot static (publication) level networks

## API

```@index
Pages = ["Plotting.md"]
```

```@autodocs
Modules = [ShadowGraphs]
Pages = ["Plotting.jl"]
```