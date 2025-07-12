# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

import Test

Test.@testset "Package ScopedSettings" begin
    include("test_aqua.jl")
    include("test_get_preference.jl")
    include("test_scoped_setting.jl")
    include("test_docs.jl")
end # testset
