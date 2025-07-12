# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

using ScopedSettings
using Test

using ScopedValues: @with, with


@testset "scoped_setting" begin
    @test @inferred(ScopedSetting(42)) isa ScopedSetting{Int, Returns{Int}}
    @test @inferred(ScopedSetting(GetPreference(ScopedSettings, "some_pref", :green))) isa ScopedSetting{Symbol, GetPreference{Symbol, Nothing}}

    # Test type stability when default is custom function:
    @test @inferred(ScopedSetting(() -> rand(Float32)^(1//2))) isa ScopedSetting{Float32}
    @test @inferred(ScopedSetting(() -> rand(Float32)^(1//2))[]) isa Float32

    # Test type stability when default is a type ctor:
    @test ScopedSetting(Symbol) isa ScopedSetting{Symbol, Type{Symbol}}
    @test @inferred(ScopedSetting(Symbol)[]) == Symbol()

    s_a = ScopedSetting(42)
    s_b = ScopedSetting(GetPreference(ScopedSettings, "some_pref", :green))

    delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
    @test @inferred(s_a[]) == 42
    @test @inferred(s_b[]) == :green

    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "blue"
    @test @inferred(s_a[]) == 42
    @test @inferred(s_b[]) == :blue

    s_a[] = 11
    s_b[] = :turquoise
    @test @inferred(s_a[]) == 11
    @test @inferred(s_b[]) == :turquoise

    let s_a = s_a, s_b = s_b
        @test @inferred(
            with(() -> (s_a[], s_b[]), s_a => 21, s_b => :violet)
        ) == (21, :violet)

        @test @inferred(
            with(() -> (s_a[], s_b[]), s_a._scopedval => 21, s_b => :violet)
        ) == (21, :violet)

        @test @inferred(
            with(() -> (s_a[], s_b[]), s_a => 21, s_b._scopedval => :violet)
        ) == (21, :violet)

        @test @inferred(
            with(() -> (s_a[], s_b[]), s_a._scopedval => 21, s_b._scopedval => :violet)
        ) == (21, :violet)


        @test @inferred((
            () -> @with s_a => 21 s_b => :violet (s_a[], s_b[])
        )()) == (21, :violet)

        @test @inferred((
            () -> @with s_a._scopedval => 21 s_b => :violet (s_a[], s_b[])
        )()) == (21, :violet)

        @test @inferred((
            () -> @with s_a => 21 s_b._scopedval => :violet (s_a[], s_b[])
        )()) == (21, :violet)

        @test @inferred((
            () -> @with s_a._scopedval => 21 s_b._scopedval => :violet (s_a[], s_b[])
        )()) == (21, :violet)
    end
end
