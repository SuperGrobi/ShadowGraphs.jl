function Folium.draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}
    kw = Dict{Symbol, Any}(kwargs)
    println(kw)
    if series_type === :vertices
        kw[:radius] = get(kw, :radius, 2)
        kw[:color] = get(kw, :color, "#e2b846")
        for vertex in vertices(g)
            lon = get_prop(g, vertex, :lon)
            lat = get_prop(g, vertex, :lat)
            draw!(fig, lon, lat, :circle; kw...)
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
            linestring = get_prop(g, edge, :edgegeom)
            draw!(fig, linestring; kw...)
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