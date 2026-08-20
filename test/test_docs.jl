# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

using Test
using ScopedSettings
import Documenter

Documenter.DocMeta.setdocmeta!(
    ScopedSettings,
    :DocTestSetup,
    :(using ScopedSettings);
    recursive=true,
)
# Make Int32/Int64 in doctest output word-size agnostic:
Documenter.doctest(ScopedSettings; doctestfilters = [r"Int(32|64)"])
