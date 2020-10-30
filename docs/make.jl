using MinimalRides
using Documenter

makedocs(;
    modules=[MinimalRides],
    authors="Andrey Oskin",
    repo="https://github.com/Arkoniak/MinimalRides.jl/blob/{commit}{path}#L{line}",
    sitename="MinimalRides.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Arkoniak.github.io/MinimalRides.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Arkoniak/MinimalRides.jl",
)
