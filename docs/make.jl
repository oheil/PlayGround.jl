using Documenter, PlayGround

makedocs(;
    modules=[PlayGround],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/oheil/PlayGround.jl/blob/{commit}{path}#L{line}",
    sitename="PlayGround.jl",
    authors="oheil <git@heilbit.de>",
    assets=String[],
)

deploydocs(;
    repo="github.com/oheil/PlayGround.jl",
)
