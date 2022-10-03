module ShadowGraphs
using LightOSM
using LightXML
using Graphs
using MetaGraphs
using ProgressMeter
using ArchGDAL

# TODO: this is a duplicate from Composite Buildings. Something like this should idealy
# be integrated into archGDAL itself...
OSM_ref() = ArchGDAL.importEPSG(4326; order=:trad)
function apply_wsg_84!(geom)
    ArchGDAL.createcoordtrans(OSM_ref(), OSM_ref()) do trans
        ArchGDAL.transform!(geom, trans)
    end
end


export shadow_graph_from_object, shadow_graph_from_file, shadow_graph_from_download
include("buildGraph.jl")

end
