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
using WebIO
using Folium
flm = pyimport("folium")

struct FoliumDrawer
    x::PyObject
end
function Base.show(io::IO, ::MIME"juliavscode/html", map::FoliumDrawer)
    write(io, repr("text/html", map.x))
end

g_shadow = shadow_graph_from_file("../../data/nottingham/clifton/test_clifton_bike.json"; network_type=:bike);

save_graph_to_csv("dir/test.csv", g_shadow)
save_graph_to_csv("test.csv", g_shadow)
save_graph_to_csv("dir/test", g_shadow)
save_graph_to_csv("test", g_shadow; remove_internal_data=true)

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
    g, g_nav = shadow_graph_from_file("../../data/nottingham/test_nottingham.json");
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
        flm.PolyLine(locs, color = way.tags["oneway"] ? "red" : "green", weight=5).add_to(m)
        #flm.PolyLine(locs, color="#" * hex(RGB(rand(), rand(), rand())), weight=5).add_to(m)
    end

    for i in zip(y,x)
        flm.Circle(location=i, radius=1).add_to(m)
    end
    for i in 1:nv(g_nav)
        lat = get_prop(g_nav, i, :lat)
        lon = get_prop(g_nav, i, :lon)
        flm.Circle(location=(lat, lon), radius=get_prop(g_nav, i, :osm_id)==0 ? 10 : 3, color=get_prop(g_nav, i, :end) ? "red" : "green", popup="osm id = $(get_prop(g_nav, i, :osm_id))").add_to(m)
    end

    for edge in edges(g_nav)
        sla = get_prop(g_nav, src(edge), :lat) + 0.0001 *rand()
        slo = get_prop(g_nav, src(edge), :lon)+ 0.0001 *rand()
        dla = get_prop(g_nav, dst(edge), :lat)+ 0.0001 *rand()
        dlo = get_prop(g_nav, dst(edge), :lon)+ 0.0001 *rand()
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
add_edge!(myg, 1,2)
add_edge!(myg, 1, 1)

gplot(myg, nodelabel=[1,2])

add_edge!(myg, 1,2)

first(g.nodes).second

fieldnames(Node)
myn = g.nodes[323238120].location.lat

g.node_to_index[1849955849]
g.index_to_node[1941]
inneighbors(g.graph, 932)
outneighbors(g.graph, 932)

neighbors(g.graph, 932)

first(g.ways).second

filter(x->x.second.tags["oneway"], g.ways)

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
m = Leaflet.Map(; layers=layer, provider=provider, zoom=3, height=1000, center=[30.0, 120.0]);
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
    if n==1
        return l(true)
    else
        return nth(l(false), n-1)
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

line = Way(1, [10,20,30,40,50,60,70,80], Dict("oneway"=>false, "reverseway"=>false, "name"=>"line"))
ring = Way(2, [10,20,30,40,50,60,70,80, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"ring"))

loli = Way(3, [10,20,30,40,50,60,70, 30], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
loli_reverse = Way(4, [10,20,30,40,10, 50, 60], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))

stresstest_open = Way(5, [10, 20, 30, 40, 50, 60, 70, 50, 30, 80, 90], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
stresstest_closed = Way(6, [10, 20, 30, 40, 20, 50, 60, 60, 70, 10], Dict("oneway"=>false, "reverseway"=>false, "name"=>"loli"))
ShadowGraphs.decompose_way_to_primitives(ring)

g_osm = graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)

begin
    fig = draw(g, :vertices; figure_params=Dict(:location=>(52.904, -1.18), :zoom_start=>14))
    draw!(fig, g, :edges)
    draw!(fig, g, :edgegeom)
end

g_osm.graph


g_osm.node_to_way

g_osm.ways

ShadowGraphs.add_this_node(g_osm, 323203074)


a = try
    a = [1,2,3][6]
catch
end
a


fig = draw(g, :vertices;
        figure_params=Dict(:location=>(52.904, -1.18), :zoom_start=>14),
        radius=3,
        color=:red)
    draw!(fig, g, :edges; color=:red, opacity=0.5, weight=5)
    draw!(fig, g, :edgegeom, opacity=0.5, weight=5)


go = graph_from_file("rings.json", network_type=:bike)
testway = go.ways[29399082]

ShadowGraphs.get_node_list(testway, 323740118, [323740118], 1)