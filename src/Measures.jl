"""
    tag_edge_bearings!(g::AbstractMetaGraph)

calculates the [bearing](https://en.wikipedia.org/wiki/Bearing_(angle)) of each `:sg_street_geometry`
and attaches it to the respective edge as `:ms_bearing`. Helpers and self edges are ignored.
"""
function tag_edge_bearings!(g::AbstractMetaGraph)
    bearings = Float64[]
    lengths = Float64[]
    project_local!(g)
    for e in filter_edges(g, :sg_helper, false)
        if !(get_prop(g, src(e), :sg_helper) && get_prop(g, dst(e), :sg_helper))  # ignores self loops
            set_prop!(g, e, :ms_bearing, single_bearing(get_prop(g, e, :sg_street_geometry)))
        end
    end
    project_back!(g)
    g
end

"""
    single_bearing(line)

calculates the [bearing](https://en.wikipedia.org/wiki/Bearing_(angle)) of a single `ArchGDAL linestring`.
Assumes the line is in a local coordinate system.
"""
function single_bearing(line)
    a = GeoInterface.coordinates(ArchGDAL.pointalongline(line, 0.0))
    b = GeoInterface.coordinates(ArchGDAL.pointalongline(line, ArchGDAL.geomlength(line)))
    return mod(90 - rad2deg(angle(complex((b - a)...))), 360)
end

"""
    bearing_histogram(g::AbstractMetaGraph; weight=nothing, nbins=36, binshift=-180 / nbins, refresh_bearings=false)

fits a histogram to the bearings stored in the `:ms_bearing` properties of edges. If `refresh_bearings=true`,
the bearings are updated/initialised before fitting.

# keyword arguments
- `weight`: name of property on the graphs edges to use as weights for the histogram. (for examle `:sg_street_length`. Is set to `nothing`, weight will be 1 for each edge.)
- `nbins`: number of bins for the histogram.
- `binshift`: offset for bins, in degrees. (use this if your bearings end up on bin edges.)
- `refresh_bearings`: if the bearings should be (re-) calculated before fitting the histogram.
The resulting bins will span from `binshift` to `360+binshift`.

returns count histogram of bearings.
"""
function bearing_histogram(g::AbstractMetaGraph; weight=nothing, nbins=36, binshift=-180 / nbins, refresh_bearings=false)
    if refresh_bearings
        tag_edge_bearings!(g)
    end

    bearing_edges = filter_edges(g, :ms_bearing)
    @assert !isempty(bearing_edges) "There are no edges with the :ms_bearing tag. Did you forget the run `tag_edge_bearings!` on your graph?"

    # do some fiddling to get everyting into the shifted range.
    bearings = [mod(get_prop(g, e, :ms_bearing) - binshift, 360) + binshift for e in bearing_edges]
    bin_edges = range(binshift, 360.0 + binshift, nbins + 1)

    if isnothing(weight)
        fit(Histogram, bearings, bin_edges)
    else
        weights = Weights([get_prop(g, e, weight) for e in bearing_edges])
        fit(Histogram, bearings, weights, bin_edges)
    end
end

@doc raw"""
    orientation_entropy(hist::Histogram)

calculates the entropy of the (continuous) distribution approximated by `hist` according to:

``H=-\int{\rho\ln(\rho)\mathrm{d}x} \approx -\sum{\rho_i\ln(\rho_i)\Delta x_i}``

where ``\Delta x_i`` is the width of the i-th bin.

There is nothing inherently `orientation` about this function. It should just work with
any general distribution you throw at it.
"""
function orientation_entropy(hist::Histogram)
    prob_hist = normalize(hist, mode=:pdf)
    bin_widths = diff(prob_hist.edges...)

    mapreduce(+, prob_hist.weights, bin_widths) do p, w
        result = -w * p * log(p)
        return iszero(p) ? zero(result) : result
    end
end


@doc raw"""
    orientation_order(hist::Histogram)

calculates the orientation order of a `hist`, defined as:

``\varphi = 1-\left(\frac{H-H_{min}}{H_{max}-H_{min}}\right)^2``

where ``H_{min}`` is the entropy of a perfect grid and ``H_{max}`` is the entropy of the constant orientation distribution.

The grid entropy is only (somewhat) defined for distributions with constant bin widths, so we check if `hist`
fulfills this condition. I am not sure if I would trust this value.
"""
function orientation_order(hist::Histogram)
    prob_hist = normalize(hist, mode=:pdf)
    bin_widths = diff(prob_hist.edges...)
    @show bin_widths
    @assert allequal(bin_widths) "the entropy of the grid is only defined for constant bin width."

    H_min = -log(0.25) + log(first(bin_widths))
    H_max = log(length(bin_widths)) + log(first(bin_widths))

    H = orientation_entropy(hist)

    return 1 - ((H - H_min) / (H_max - H_min))^2
end