"""
    draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}

draws the given data series properies of the graph into a `Folium.jl` map.

# arguments
- fig::FoliumMap: map to draw in
- g: shadow graph carying the data
- series_type: type of data to draw from the graph. Pick from: `:vertices`, `:edges`, `:edgegeom`, `:shadowgeom`.
- kwargs: keywords passed to folium for every `series_type`. (see the [python docs](https://python-visualization.github.io/folium/) and the [leaflet docs](https://leafletjs.com/reference.html) for a full list of all options.) 

Every `series_type` has a few sensible defaults set,
most importantly the default tooltips and popups, which, by default show some interesting data about the vertices and edges, respectively.
Currently, the `kwargs` are set for every element, there is (currently) no way to set parameters with, for example a vector, to get a element by
element arguments.

# returns
- fig::FoliumMap (passthrough of argument)
"""
function Folium.draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}
    kw = Dict{Symbol, Any}(kwargs)
    if series_type === :vertices
        kw[:radius] = get(kw, :radius, 2)
        kw[:color] = get(kw, :color, "#e2b846")
        for vertex in vertices(g)
            tt = "osm id: $(has_prop(g, vertex, :osm_id) ? get_prop(g, vertex, :osm_id) : 0)<br>graph vertex: $vertex"
            lon = get_prop(g, vertex, :lon)
            lat = get_prop(g, vertex, :lat)
            draw!(fig, lon, lat, :circle; tooltip=tt, popup=tt, kw...)
        end
    elseif series_type === :edges
        kw[:opacity] = get(kw, :opacity, 0.5)
        kw[:weight] = get(kw, :weight, 2)
        kw[:color] = get(kw, :color, "#e56c6c")
        for edge in edges(g)
            sla = get_prop(g, src(edge), :lat)
            slo = get_prop(g, src(edge), :lon)
            dla = get_prop(g, dst(edge), :lat)
            dlo = get_prop(g, dst(edge), :lon)
            draw!(fig, [slo, dlo], [sla, dla], :line; kw...)
        end
    elseif series_type === :edgegeom
        for edge in edges(g)
            !has_prop(g, edge, :edgegeom) && continue
            id = has_prop(g, edge, :osm_id) ? get_prop(g, edge, :osm_id) : 0
            shadowed_length = has_prop(g, edge, :shadowed_length) ? get_prop(g, edge, :shadowed_length) : 0
            full_length = has_prop(g, edge, :full_length) ? get_prop(g, edge, :full_length) : -1
            tt = "osm id: $id<br>shadow length: $(round(shadowed_length; digits=2))<br>total length: $(round(full_length; digits=2))<br>fraction in shadow: $(round(shadowed_length/full_length; digits=2))"
            linestring = get_prop(g, edge, :edgegeom)
            draw!(fig, linestring; tooltip=tt, popup=tt, kw...)
        end
    elseif series_type === :shadowgeom
        kw[:color] = get(kw, :color, "black")
        for edge in edges(g)
            !has_prop(g, edge, :shadowgeom) && continue
            line = get_prop(g, edge, :shadowgeom)
            draw!(fig, line; kw...)
        end
    else
        throw(ArgumentError("the series type $series_type is not supported. Available types are: [:vertices, :edges, :edgegeom, :shadowgeom]"))
    end
    return fig
end

"""
    draw(g::T, series_type::Symbol; figure_params=Dict(), kwargs...) where {T<:AbstractMetaGraph}

same as `draw!`, but creates a new `FoliumMap` first.

# argumnents
- same as `draw!` plus:
- figure_params: dictionary with arguments which are getting passed to the `FoliumMap` constructor (see the [python docs](https://python-visualization.github.io/folium/) and the [leaflet docs](https://leafletjs.com/reference.html) for a full list of all options.)

# returns
- the newly created figure
"""
function Folium.draw(g::T, series_type::Symbol; figure_params=Dict(), kwargs...) where {T<:AbstractMetaGraph}
    fig = FoliumMap(; figure_params...)
    return draw!(fig, g, series_type; kwargs...)
end