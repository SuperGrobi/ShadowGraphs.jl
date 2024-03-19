using ShadowGraphs
using Documenter

DocMeta.setdocmeta!(ShadowGraphs, :DocTestSetup, :(using ShadowGraphs); recursive=true)

makedocs(;
    modules=[ShadowGraphs],
    authors="Henrik Wolf <henrik-wolf@freenet.de> and contributors",
    repo="https://github.com/SuperGrobi/ShadowGraphs.jl/blob/{commit}{path}#{line}",
    sitename="ShadowGraphs.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://SuperGrobi.github.io/ShadowGraphs.jl",
        edit_link="main",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Graph creation" => "BuildGraph.md",
        "Graph saving (and loading)" => "Persistence.md",
        "Graph Measures" => "Measures.md",
        "Pedestrianization"=> "Pedestrianization.md",
        "Plotting" => "Plotting.md",
        "Projection" => "Projection.md",
        "RTree Building" => "RTreeBuilding.md"
    ]
)

custom_css_path = joinpath(@__DIR__, "build", "assets", "custom_theme_overwrites.css")

for themefile in readdir(joinpath(@__DIR__, "build", "assets", "themes"), join=true)
    open(themefile, append=true) do f
        write(f, read(custom_css_path))
    end
end

deploydocs(;
    repo="github.com/SuperGrobi/ShadowGraphs.jl",
    devbranch="main"
)
