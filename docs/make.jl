using Documenter

try
    using HungarianAlgorithm
catch
    if !("../src/" in LOAD_PATH)
       push!(LOAD_PATH,"../src/")
       @info "Added \"../src/\"to the path: $LOAD_PATH "
       using HungarianAlgorithm
    end
end

makedocs(
    sitename = "HungarianAlgorithm",
    format = format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    modules = [HungarianAlgorithm],
    pages = ["index.md", "reference.md"],
    doctest = true
)

deploydocs(
    repo ="github.com/arash-dehghan/HungarianAlgorithm.jl.git",
    target="build"
)
