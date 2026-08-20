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
        piracies = false,
        stale_deps = (ignore = [:ScopedValues],)
    )

    # On Julia < v1.13 the with/Scope methods for mixed
    # ScopedSetting/ScopedValue pairs are intentional piracy (they also match
    # foreign-only signatures, but are never dispatched for those since the
    # ScopedValues methods are more specific). Pin the exact count so that any
    # new piracy still fails the test:
    n_expected_piracies = ScopedSettings._HAS_ABSTRACT_SCOPED_VALUE ? 0 : 2
    Test.@test length(Aqua.Piracy.hunt(ScopedSettings)) == n_expected_piracies
end # testset
