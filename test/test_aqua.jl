# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

import Test
import Aqua
import ScopedSettings

Test.@testset "Package ambiguities" begin
    # Cross-module check, but ignore ambiguities among Base/Core methods themselves:
    ambiguities = Test.detect_ambiguities(ScopedSettings, Base, Core; recursive = true)
    Test.@test isempty(filter(ms -> any(m -> m.module === ScopedSettings, ms), ambiguities))
end # testset

Test.@testset "Aqua tests" begin
    Aqua.test_all(
        ScopedSettings;
        ambiguities = true,
        stale_deps = (ignore = [:ScopedValues],) 
    )
end # testset
