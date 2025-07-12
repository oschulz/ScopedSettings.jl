# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

import Test
import Aqua
import ScopedSettings

Test.@testset "Package ambiguities" begin
    Test.@test isempty(Test.detect_ambiguities(ScopedSettings))
end # testset

Test.@testset "Aqua tests" begin
    Aqua.test_all(
        ScopedSettings,
        ambiguities = true
    )
end # testset
