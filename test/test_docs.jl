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
Documenter.doctest(ScopedSettings)
