"""
    draw!(fig::FoliumMap, g::T, series_type::Symbol; kwargs...) where {T<:AbstractMetaGraph}

draws the given data series properies of the graph into a `Folium.jl` map.

# arguments
- `fig::FoliumMap`: map to draw in. (You can leave this argument out and let the folium callstack figure things out.)
- `g`: shadow graph carying the data.
- `series_type`: type of data to draw from the graph. Pick from: `:vertices`, `:edges`, `:streets`, `:shadows` or any edge property containing data we can draw with folium.

# keyword arguments
- `draw_arrow`: if there should be a circle drawn 80% along the geometry. (only applies when `series_type` is `:streets`)
- `kwargs`: keywords passed to folium for every element of `series_type`. (see the [python docs](https://python-visualization.github.io/folium/) and the [leaflet docs](https://leafletjs.com/reference.html) for a full list of all options.)

Every `series_type` has a few sensible defaults set,
most importantly the default tooltips and popups, which, by default show some interesting data about the vertices and edges, respectively.

Currently, the `kwargs` are set for every element, there is (currently) no way to set individual parameters for each element.

# returns
- `fig::FoliumMap` (passthrough of argument)
"""
function Folium.draw!(fig::FoliumMap, g::T, series_type::Symbol; draw_arrows=true, kwargs...) where {T<:AbstractMetaGraph}
    @nospecialize
    if series_type === :vertices
        for vertex in vertices(g)
            tt = "osm id: $(get_prop(g, vertex, :sg_osm_id))<br>graph vertex: $vertex"
            lon = get_prop(g, vertex, :sg_lon)
            lat = get_prop(g, vertex, :sg_lat)
            draw!(fig, lon, lat, :circle; radius=2, color="#e2b846", tooltip=tt, popup=tt, kwargs...)
        end
    elseif series_type === :edges
        for edge in edges(g)
            sla = get_prop(g, src(edge), :sg_lat)
            slo = get_prop(g, src(edge), :sg_lon)
            dla = get_prop(g, dst(edge), :sg_lat)
            dlo = get_prop(g, dst(edge), :sg_lon)
            draw!(fig, [slo, dlo], [sla, dla], :line; opacity=0.5, weight=2, color="#e56c6c", kwargs...)
        end
    elseif series_type === :streets
        for edge in filter_edges(g, :sg_helper, false)
            id = get_prop(g, edge, :sg_osm_id)
            shadow_length = get_prop_default(g, edge, :sg_shadow_length, 0)
            street_length = get_prop_default(g, edge, :sg_street_length, -1)
            tt = "osm id: $id<br>shadow length: $(round(shadow_length; digits=2))<br>street length: $(round(street_length; digits=2))<br>fraction in shadow: $(round(shadow_length/street_length; digits=2))"
            linestring = get_prop(g, edge, :sg_street_geometry)
            draw!(fig, linestring; tooltip=tt, popup=tt, kwargs...)
            draw_arrows && draw!(fig, ArchGDAL.pointalongline(linestring, 0.8 * ArchGDAL.geomlength(linestring)); fill=true, fill_opacity=1, radius=1.0, kwargs...)
        end
    elseif series_type === :shadows
        for edge in filter_edges(g, :sg_shadow_geometry)
            line = get_prop(g, edge, :sg_shadow_geometry)
            draw!(fig, line; color=:black, kwargs...)
        end
    else
        # try and draw the seriestype directly from the edges
        filtered_edges = filter_edges(g, series_type)
        if !isempty(filtered_edges)
            for edge in filtered_edges
                geometry = get_prop(g, edge, series_type)
                draw!(fig, geometry; kwargs...)
            end
        else
            throw(ArgumentError("the series type $series_type did not produce any plotable data. Available types are: [:vertices, :edges, :streets, :shadows] and edge-`props` with Folium-plottable data."))
        end
    end
    return fig
end

"""

    draw!(fig::FoliumMap, g::T, path::AbstractVector; kwargs...) where {T<:AbstractMetaGraph} 

draws the `path` given by node ids in `g` into `fig`. Uses the `:sg_geometry`-field of the nodes and the `:sg_street_geometry` field of the edges.
`kwargs` are applied to both, cirles and lines. Does some fancy stuff to connect the lines when possible.

returns
`fig` (passthrough)
"""
function Folium.draw!(fig::FoliumMap, g::T, path::AbstractVector; kwargs...) where {T<:AbstractMetaGraph}
    @nospecialize
    streetgeoms = [get_prop(g, s, d, :sg_street_geometry) for (s, d) in zip(path[1:end-1], path[2:end]) if has_prop(g, s, d, :sg_street_geometry)]
    streetgeoms_coords = map(GeoInterface.coordinates, streetgeoms)

    # build our own set of points, for pretty plotting
    points_new = [streetgeoms_coords[1][1]]
    start_index = 2
    for i in 1:length(streetgeoms)-1
        ep1 = streetgeoms_coords[i]
        ep2 = streetgeoms_coords[i+1]
        if GeoInterface.intersects(streetgeoms[i], streetgeoms[i+1])
            for j in start_index:length(ep1)
                did_intersect = false
                for k in 1:length(ep2)-1
                    if switches_side(points_new[end], ep1[j], ep2[k], ep2[k+1])
                        strech_factor = intersection_distances(points_new[end], ep1[j], ep2[k], ep2[k+1])[1]
                        if 0.0 < strech_factor < 1.0
                            push!(points_new, (1 - strech_factor) * points_new[end] + strech_factor * (ep1[j]))
                            start_index = k + 1
                            did_intersect = true
                            break
                        end
                    end
                end
                if !did_intersect
                    push!(points_new, ep1[j])
                end
            end
        else
            points_new = [points_new; ep1[start_index:end]]
            start_index = 1
        end
    end
    points_new = [points_new; streetgeoms_coords[end][start_index:end]]
    lons = mapfoldl(points -> getindex.(points, 1), vcat, streetgeoms_coords)
    lats = mapfoldl(points -> getindex.(points, 2), vcat, streetgeoms_coords)
    draw!(fig, lons, lats, :line; kwargs...)
    # draw!(fig, getindex.(points_new, 1), getindex.(points_new, 2), :line, ; color=:green, weight=10)

    for n in path
        point = get_prop(g, n, :sg_geometry)
        tt = "osm id: $(get_prop(g, n, :sg_osm_id))<br>graph vertex: $n"
        draw!(fig, point; radius=1.0, fill_opacity=1, fill=true, tooltip=tt, popup=tt, kwargs...)
    end
    return fig
end

graph_extent(g) = geoiter_extent(get_prop(g, v, :sg_geometry) for v in vertices(g))