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
flm = pyimport("folium")

struct FoliumDrawer
    x::PyObject
end
function Base.show(io::IO, ::MIME"juliavscode/html", map::FoliumDrawer)
    write(io, repr("text/html", map.x))
end


g_nav
get_prop(g_nav, 40, :osm_id)
g.node_to_way
g.node_to_way[323232723]

g.node_to_way[323233148]
g.ways
29387982
29387958

29387946
29387958
begin
    g, g_nav = shadow_graph_from_file("test_nottingham.json");
    x = [i[2] for i in g.node_coordinates]
    y = [i[1] for i in g.node_coordinates]
    x_nav = [get_prop(g_nav, i, :lon) for i in vertices(g_nav)]
    y_nav = [get_prop(g_nav, i, :lat) for i in vertices(g_nav)]
end;

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
        if has_prop(g_nav, edge, :geolinestring) && length(get_prop(g_nav, edge, :geolinestring)) == 0
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
    points = [get_prop(g_nav, i, :geopoint) for i in vertices(g_nav) if has_prop(g_nav, i, :geopoint)]
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