using ShadowGraphs
using LightOSM
using Graphs
using GraphPlot
using Compose
using MetaGraphs
using Plots
using GeoInterface
using GraphRecipes
using ArchGDAL
using PyCall
using Colors
using Folium
using CoolWalksUtils

using BenchmarkTools

@benchmark shadow_graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike)
@benchmark shadow_graph_from_file("../../data/nottingham/nottingham_bike_full.json"; network_type=:bike)

gs = shadow_graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike)

draw(gs, p2; figure_params=Dict(:zoom_start => 4))

p1 = [1, 785, 446, 1584, 1527, 49, 764, 1375, 115]  # normal edges
p2 = [1692, 420, 1119, 533, 598, 5, 1632]  # helper nodes at start and end, edge 5 => 1632 is helper edge
for i in [:vertices, :edges, :streets, :shadows, :sg_street_geometry, p1, p2]
    try
        draw(g, i; figure_params=Dict(:zoom_start => 14))
        @test true
    catch
        @test "error thrown in plotting graph (from scratch) with $i"
    end
end


props(gs, 1)

g_shadow = shadow_graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike);
g_s1 = shadow_graph_from_file("../../data/nottingham/nottingham_bike_full.json"; network_type=:bike);
g_s2 = shadow_graph_from_file("../../data/nottingham/nottingham_bike_full.json"; network_type=:bike);

g_s1[2]
g_s2[2]

tag = :full_length
for e in filter_edges(g_s2[2], tag)
    p1 = get_prop(g_s1[2], e, tag)
    p2 = get_prop(g_s2[2], e, tag)
    if p1 != p2
        @warn p1 p2 e
        break
    end
end

e = Edge(32, 3034)

a2 = sum(filter_edges(g_s2[2], :full_length)) do e
    get_prop(g_s2[2], e, :full_length)
end

a1 - a2

g_light = graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike);



@profview shadow_graph_from_file("../../data/nottingham/nottingham_bike_full.json"; network_type=:bike);
@profview shadow_graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike);


shadow_graph_from_file("test_nottingham_bike.json"; network_type=:bike);

g_shadow


a, b = geoiter_extent(get_prop(g_shadow, v, :pointgeom) for v in vertices(g_shadow))
a

g_shadow

bearings, lengths = edge_bearings(g_shadow)

histogram(bearings, weights=lengths)

extrema(bearings)

-eps(0.0)


draw(g_shadow, :vertices)
draw!(get_prop(g_shadow, first(edges(g_shadow)), :edgegeom))

props(g_shadow, first(edges(g_shadow)))

begin
    project_local!(g_shadow)
    b = single_bearing(get_prop(g_shadow, first(edges(g_shadow)), :edgegeom))
    project_back!(g_shadow)
    b
end


plot([0.0, b], ratio=1, xlims=(-2, 2), ylims=(-2, 2), framestyle=:box, arrow=true)



g_shadow
props(g_shadow, first(edges(g_shadow)))

export_graph_to_csv("test/data/test.csv", g_shadow)

es = import_graph_from_csv("test/data/test")

g_light.ways

fwds = [get(i.second.tags, "lanes:backward", "hallo") for i in g_light.ways]


k = Set(vcat(collect.(keys.([get_prop(g_shadow, edge, :tags) for edge in edges(g_shadow) if has_prop(g_shadow, edge, :tags)]))...))

[get_prop(g_shadow, edge, :tags) for edge in edges(g_shadow) if has_prop(g_shadow, edge, :tags)]

plot([get_prop(g_shadow, node, :pointgeom) for node in vertices(g_shadow)], ratio=1)

g_shadow



parsed
orig

mis = [i for i in keys(parsed) if !(i in keys(orig))]
mis = [i for i in keys(orig) if !(i in keys(parsed))]

begin
    g, g_nav = shadow_graph_from_file("../../data/nottingham/test_nottingham.json")
    x = [i[2] for i in g.node_coordinates]
    y = [i[1] for i in g.node_coordinates]
    x_nav = [get_prop(g_nav, i, :lon) for i in vertices(g_nav)]
    y_nav = [get_prop(g_nav, i, :lat) for i in vertices(g_nav)]
end;

draw(g_nav, :edgegeom)

begin
    m = flm.Map()

    for (way_id, way) in g.ways
        nodes = [g.nodes[i] for i in way.nodes]
        locs = [(node.location.lat, node.location.lon) for node in nodes]
        flm.PolyLine(locs, color=way.tags["oneway"] ? "red" : "green", weight=5).add_to(m)
        #flm.PolyLine(locs, color="#" * hex(RGB(rand(), rand(), rand())), weight=5).add_to(m)
    end

    for i in zip(y, x)
        flm.Circle(location=i, radius=1).add_to(m)
    end
    for i in 1:nv(g_nav)
        lat = get_prop(g_nav, i, :lat)
        lon = get_prop(g_nav, i, :lon)
        flm.Circle(location=(lat, lon), radius=get_prop(g_nav, i, :osm_id) == 0 ? 10 : 3, color=get_prop(g_nav, i, :end) ? "red" : "green", popup="osm id = $(get_prop(g_nav, i, :osm_id))").add_to(m)
    end

    for edge in edges(g_nav)
        sla = get_prop(g_nav, src(edge), :lat) + 0.0001 * rand()
        slo = get_prop(g_nav, src(edge), :lon) + 0.0001 * rand()
        dla = get_prop(g_nav, dst(edge), :lat) + 0.0001 * rand()
        dlo = get_prop(g_nav, dst(edge), :lon) + 0.0001 * rand()
        color = "grey"
        if has_prop(g_nav, edge, :edgegeom) && ngeom(get_prop(g_nav, edge, :edgegeom)) == 0
            color = "orange"
        end
        flm.PolyLine([(sla, slo), (dla, dlo)], color=color, weight=5).add_to(m)
    end

    bounds = [(minimum(y), minimum(x)), (maximum(y), maximum(x))]
    m.fit_bounds(bounds)
    drawer = FoliumDrawer(m)
end

typeof(m)

figure = compose(gplot(g.graph, 10 .* x, -10 .* y, arrowlengthfrac=0.003, nodesize=0.1),
    gplot(g_nav, x_nav, -y_nav))



draw(SVG("graph2.svg", 10cm, 10cm), gplot(g_nav, x_nav, -y_nav, arrowlengthfrac=0.003, nodesize=0.1))
gplot(g.graph, 10 .* x, -10 .* y, arrowlengthfrac=0)
gplot(g_nav, x_nav, -y_nav)


graphplot(g.graph, x=x, y=y, curves=false, nodesize=0.0001, nodestrokewidth=0.001, axisbuffer=0.01)
graphplot(g.graph, x=x, y=y, curves=false)
scatter!([x_nav[1]], [y_nav[1]])
scatter!(x_nav, y_nav)
props(g_nav, 1)
props(g_nav, 2)
g.node_to_way

keys(g.nodes)

fieldnames(GeoLocation)

g.node_to_index[323238122]
g.node_to_way[323238122]

[g.index_to_node[i] for i in outneighbors(g.graph, 2552)]

myg = MetaDiGraph(2)
add_edge!(myg, 1, 2)
add_edge!(myg, 1, 1)

gplot(myg, nodelabel=[1, 2])

add_edge!(myg, 1, 2)

first(g.nodes).second

fieldnames(Node)
myn = g.nodes[323238120].location.lat

g.node_to_index[1849955849]
g.index_to_node[1941]
inneighbors(g.graph, 932)
outneighbors(g.graph, 932)

neighbors(g.graph, 932)

first(g.ways).second

filter(x -> x.second.tags["oneway"], g.ways)

fieldnames(Way)

collect(vertices(g_nav))

first(g.ways).second.nodes


g = SimpleDiGraph(4)

for i in vertices(g)
    add_vertex!(g)
end
hasproperty
has_prop
g

begin
    points = [(get_prop(g_nav, i, :lon), get_prop(g_nav, i, :lat)) for i in vertices(g_nav) if !get_prop(g_nav, i, :helper)]
    layer = Leaflet.Layer.(points)
    provider = Leaflet.CARTO(:dark_nolabels)
    m = Leaflet.Map(; layers=layer, provider=provider, zoom=3, height=1000, center=[30.0, 120.0])
    w = Blink.Window()
    body!(w, m)
end

fieldnames(Way)

using Leaflet
using Blink
provider = Leaflet.CARTO(:dark_nolabels)
m = Leaflet.Map(; layers=Leaflet.Layer[], provider=provider, zoom=3, height=1000, center=[30.0, 120.0])

w = Blink.Window()
body!(w, m)

m
WebIO.render(m)
m.scope.dom

fieldnames(Leaflet.Map)

a = WebIO.render(m)
typeof(a)

fieldnames(WebIO.Node)


cons(h, t) = w -> w ? h : t
x = cons(1, cons(2, cons(3, nothing)))

x(false)(false)(true)

function nth(l, n)
    if n == 1
        return l(true)
    else
        return nth(l(false), n - 1)
    end
end

nth(x, 3)

function prnlist(l)
    print("(")
    _prnlist(l) = l === nothing ? print("") : (print(l(true)); print(" "); _prnlist(l(false)))
    _prnlist(l)
    println(")")
end

prnlist(x)

line = Way(1, [10, 20, 30, 40, 50, 60, 70, 80], Dict("oneway" => false, "reverseway" => false, "name" => "line"))
ring = Way(2, [10, 20, 30, 40, 50, 60, 70, 80, 10], Dict("oneway" => false, "reverseway" => false, "name" => "ring"))

loli = Way(3, [10, 20, 30, 40, 50, 60, 70, 30], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
loli_reverse = Way(4, [10, 20, 30, 40, 10, 50, 60], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))

stresstest_open = Way(5, [10, 20, 30, 40, 50, 60, 70, 50, 30, 80, 90], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
stresstest_closed = Way(6, [10, 20, 30, 40, 20, 50, 60, 60, 70, 10], Dict("oneway" => false, "reverseway" => false, "name" => "loli"))
ShadowGraphs.decompose_way_to_primitives(ring)

g_osm = graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

begin
    fig = draw(g, :vertices; figure_params=Dict(:location => (52.904, -1.18), :zoom_start => 14))
    draw!(fig, g, :edges)
    draw!(fig, g, :edgegeom)
end

g_osm.graph


g_osm.node_to_way

g_osm.ways

ShadowGraphs.add_this_node(g_osm, 323203074)


a = try
    a = [1, 2, 3][6]
catch
    3
end
a


fig = draw(g, :vertices;
    figure_params=Dict(:location => (52.904, -1.18), :zoom_start => 14),
    radius=3,
    color=:red)
draw!(fig, g, :edges; color=:red, opacity=0.5, weight=5)
draw!(fig, g, :edgegeom, opacity=0.5, weight=5)


go = graph_from_file("rings.json", network_type=:bike)
testway = go.ways[29399082]

a = 1

"value = $a"
f(x) = x^2

gs = shadow_graph_from_file("test/data/test_clifton_bike.json"; network_type=:bike)

export_shadow_graph_to_csv("./test/temp/gs", gs;)# edge_props=Not([:sg_helper, :sg_tags]), vertex_props=Not([:sg_helper, :sg_geometry]), graph_props=Not([:sg_crs]))

nd, ed, gd, lg = import_shadow_graph_from_csv("./test/temp/gs")

using ArchGDAL

ArchGDAL.fromWKT("test")

MetaDiGraph(:test, 0.0)


gs

tag_edge_bearings!(gs)

using LinearAlgebra
using StatsBase

bhist = ShadowGraphs.bearing_histogram(gs; binshift=-5)

ShadowGraphs.bearing_histogram(gs; binshift=-5).edges[1][1]

plot(bhist)

b1 = normalize(bhist; mode=:pdf)
b2 = normalize(bhist; mode=:density)
b3 = normalize(bhist; mode=:probability)

hists = [bhist, b1, b2, b3]

ShadowGraphs.orientation_order.(hists)

a = ShadowGraphs.orientation_order(b1)
H = mapreduce(+, a...) do p, w
    -w * p * log(p) 
end

b1.weights

fusing Plots

b1.edges

plot!(bhist)



sum(bnorm.weights)
entropy(bnorm.weights)


base_hist = fit(Histogram, rand(1:100, 1000), nbins=20)

h1 = normalize(base_hist; mode=:pdf)
h2 = normalize(base_hist; mode=:density)
h3 = normalize(base_hist; mode=:probability)

h1
h4 = normalize(h1; mode=:probability)
h2
h5 = normalize(h2; mode=:probability)


norm(h2)

norm(base_hist)
norm(h1)
norm(h2)
norm(h3)


hist = fit(Histogram, rand([10, 100, 190, 280], 100000), 360 .* ((0:0.0000001:1)))

nonlin_bins = range(0, 1, 11).^2 .* 360


hist = fit(Histogram, 360 .* rand(100000), nonlin_bins)

hn = normalize(hist, mode=:pdf)

plot(hn)


H = mapreduce(+, hn.weights, diff(hn.edges...)) do p, w
    result = - w*p * log(p)
    return iszero(p) ? zero(result) : result
end


3

hc = normalize(hist, mode=:probability)

H = mapreduce(+, hc.weights, diff(hn.edges...)) do P, w
    result = - P * log(P/w)
    return iszero(P) ? zero(result) : result
end