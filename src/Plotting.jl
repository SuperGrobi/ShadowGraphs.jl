"""
    draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}

draws the given data series properies of the graph into a `Folium.jl` map.

# arguments
- fig::FoliumMap: map to draw in
- g: shadow graph carying the data
- series_type: type of data to draw from the graph. Pick from: `:vertices`, `:edges`, `:edgegeom`, `:shadowgeom`.
- draw_arrows: if there should be a circle drawn 80% along the edgegeom. (only applies when `series_type` is `:edgegeom`)
- kwargs: keywords passed to folium for every `series_type`. (see the [python docs](https://python-visualization.github.io/folium/) and the [leaflet docs](https://leafletjs.com/reference.html) for a full list of all options.) 

Every `series_type` has a few sensible defaults set,
most importantly the default tooltips and popups, which, by default show some interesting data about the vertices and edges, respectively.
Currently, the `kwargs` are set for every element, there is (currently) no way to set parameters with, for example a vector, to get a element by
element arguments.

# returns
- fig::FoliumMap (passthrough of argument)
"""
function Folium.draw!(fig::FoliumMap, g::T, series_type::Symbol; draw_arrows=true, kwargs...) where {T<:AbstractMetaGraph}
    @nospecialize
    if series_type === :vertices
        for vertex in vertices(g)
            tt = "osm id: $(has_prop(g, vertex, :osm_id) ? get_prop(g, vertex, :osm_id) : 0)<br>graph vertex: $vertex"
            lon = get_prop(g, vertex, :lon)
            lat = get_prop(g, vertex, :lat)
            draw!(fig, lon, lat, :circle; radius=2, color="#e2b846", tooltip=tt, popup=tt, kwargs...)
        end
    elseif series_type === :edges
        for edge in edges(g)
            sla = get_prop(g, src(edge), :lat)
            slo = get_prop(g, src(edge), :lon)
            dla = get_prop(g, dst(edge), :lat)
            dlo = get_prop(g, dst(edge), :lon)
            draw!(fig, [slo, dlo], [sla, dla], :line, opacity=0.5, weight=2, color="#e56c6c", kwargs...)
        end
    elseif series_type === :edgegeom
        for edge in edges(g)
            !has_prop(g, edge, :edgegeom) && continue
            id = has_prop(g, edge, :osm_id) ? get_prop(g, edge, :osm_id) : 0
            shadowed_length = has_prop(g, edge, :shadowed_length) ? get_prop(g, edge, :shadowed_length) : 0
            full_length = has_prop(g, edge, :full_length) ? get_prop(g, edge, :full_length) : -1
            tt = "osm id: $id<br>shadow length: $(round(shadowed_length; digits=2))<br>total length: $(round(full_length; digits=2))<br>fraction in shadow: $(round(shadowed_length/full_length; digits=2))"
            linestring = get_prop(g, edge, :edgegeom)
            draw!(fig, linestring; tooltip=tt, popup=tt, kwargs...)
            draw_arrows && draw!(fig, ArchGDAL.pointalongline(linestring, 0.8 * ArchGDAL.geomlength(linestring)); fill=true, fill_opacity=1, radius=1.0, kwargs...)
        end
    elseif series_type === :shadowgeom
        for edge in edges(g)
            !has_prop(g, edge, :shadowgeom) && continue
            line = get_prop(g, edge, :shadowgeom)
            draw!(fig, line; color=:black, kwargs...)
        end
    else
        throw(ArgumentError("the series type $series_type is not supported. Available types are: [:vertices, :edges, :edgegeom, :shadowgeom]"))
    end
    return fig
end

"""

    draw!(fig::FoliumMap, g::T, path::AbstractArray; kwargs...) where {T<:AbstractMetaGraph} 

draws the `path` given by node ids in `g` into `fig`. Uses the `:pointgeom`-field of the nodes and the `:edgegeom` field of the edges.
`kwargs` are applied to both, cirles and lines.
"""
function Folium.draw!(fig::FoliumMap, g::T, path::AbstractArray; kwargs...) where {T<:AbstractMetaGraph}
    @nospecialize
    edgegeoms = map(path[1:end-1], path[2:end]) do s, d
        if has_prop(g, s, d, :edgegeom)
            return get_prop(g, s, d, :edgegeom)
        end
    end
    draw!(fig, filter(!isnothing, edgegeoms); kwargs...)
    for n in path
        point = get_prop(g, n, :pointgeom)
        tt = "osm id: $(has_prop(g, n, :osm_id) ? get_prop(g, n, :osm_id) : 0)<br>graph vertex: $n"
        draw!(fig, point; radius=1.0, fill_opacity=1, fill=true, tooltip=tt, popup=tt, kwargs...)
    end
    return fig
end