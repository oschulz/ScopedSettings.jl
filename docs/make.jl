# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [nonstrict] [fixdoctests]
#
# for local builds.

using Documenter
using ScopedSettings

# Doctest setup
DocMeta.setdocmeta!(
    ScopedSettings,
    :DocTestSetup,
    :(using ScopedSettings);
    recursive=true,
)

makedocs(
    sitename = "ScopedSettings",
    modules = [ScopedSettings],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://oschulz.github.io/ScopedSettings.jl/stable/"
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
        "LICENSE" => "LICENSE.md",
    ],
    doctest = ("fixdoctests" in ARGS) ? :fix : true,
    linkcheck = !("nonstrict" in ARGS),
    warnonly = ("nonstrict" in ARGS),
)

deploydocs(
    repo = "github.com/oschulz/ScopedSettings.jl.git",
    forcepush = true,
    push_preview = true,
)
