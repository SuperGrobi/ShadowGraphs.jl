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
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Graph creation" => "BuildGraph.md",
        "IO" => "Persistence.md",
        "Plotting" => "Plotting.md"
    ],
)

deploydocs(;
    repo="github.com/SuperGrobi/ShadowGraphs.jl",
    devbranch="main",
)
