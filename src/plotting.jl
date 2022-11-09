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
            id = has_prop(g, edge, :osm_id)
            shadowed_length = has_prop(g, edge, :shadowed_length) ? get_prop(g, edge, :shadowed_length) : 0
            total_length = has_prop(g, edge, :total_length) ? get_prop(g, edge, :total_length) : -1
            tt = "osm id: $id<br>shadow length: $shadowed_length<br>total length: $total_length<br>fraction in shadow: $(shadowed_length/total_length)"
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


function Folium.draw(g::T, series_type::Symbol; figure_params=Dict(), kwargs...) where {T<:AbstractMetaGraph}
    fig = FoliumMap(; figure_params...)
    return draw!(fig, g, series_type; kwargs...)
end