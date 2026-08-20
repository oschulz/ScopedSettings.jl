# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

using ScopedSettings
using Test

using ScopedValues: @with, with, ScopedValue


@testset "scoped_setting" begin
    @test @inferred(ScopedSetting(42)) isa ScopedSetting{Int, Returns{Int}}
    @test @inferred(ScopedSetting(GetPreference(ScopedSettings, "some_pref", :green))) isa ScopedSetting{Symbol, GetPreference{Symbol, Nothing}}

    # Test type stability when default is custom function:
    @test @inferred(ScopedSetting(() -> rand(Float32)^(1//2))) isa ScopedSetting{Float32}
    @test @inferred(ScopedSetting(() -> rand(Float32)^(1//2))[]) isa Float32

    # Test type stability when default is a type ctor:
    @test ScopedSetting(Symbol) isa ScopedSetting{Symbol, Type{Symbol}}
    @test @inferred(ScopedSetting(Symbol)[]) == Symbol()

    # Explicit-type ctor must convert value defaults:
    @test @inferred(ScopedSetting{Float64}(42)) isa ScopedSetting{Float64, Returns{Float64}}
    @test @inferred(ScopedSetting{Float64}(42)[]) === 42.0

    # Explicit-type ctor must pass functions and type ctors through:
    @test @inferred(ScopedSetting{Symbol}(GetPreference(ScopedSettings, "some_pref", :green))) isa ScopedSetting{Symbol, GetPreference{Symbol, Nothing}}
    @test @inferred(ScopedSetting{Float64}(() -> 4.2)[]) === 4.2
    @test ScopedSetting{AbstractVector}(Vector{Int}) isa ScopedSetting{AbstractVector, Type{Vector{Int}}}
    @test ScopedSetting{AbstractVector}(Vector{Int})[] == Int[]

    @test repr(ScopedSetting(42)) == "ScopedSetting{$Int}(42)"
    @test repr(ScopedSetting{Int}(() -> error("borked"))) == "ScopedSetting{$Int}(<error>)"
    @test eltype(ScopedSetting(42)) == Int

    s_a = ScopedSetting(42)
    s_b = ScopedSetting(GetPreference(ScopedSettings, "some_pref", :green))

    delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
    @test @inferred(s_a[]) == 42
    @test @inferred(s_b[]) == :green

    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "blue"
    @test @inferred(s_a[]) == 42
    @test @inferred(s_b[]) == :blue

    @test setindex!(s_a, 11) === s_a
    s_b[] = :turquoise
    @test @inferred(s_a[]) == 11
    @test @inferred(s_b[]) == :turquoise

    @test_throws MethodError s_a[] = nothing
    @test_throws MethodError with(() -> s_a[], s_a => default_value)
    @test_throws MethodError @with s_a => default_value s_a[]

    with(s_a => 21) do
        @test_throws ErrorException s_a[] = 0
        @test_throws ErrorException s_a[] = default_value
    end
    @test s_a[] == 11

    s_a[] = default_value
    s_b[] = default_value
    @test @inferred(s_a[]) == 42
    @test @inferred(s_b[]) == :blue

    s_a[] = 11
    s_b[] = :turquoise

    sv = ScopedValue(0)

    let s_a = s_a, s_b = s_b, sv = sv
        @test @inferred(
            with(() -> (s_a[], s_b[]), s_a => 21, s_b => :violet)
        ) == (21, :violet)

        @test @inferred(
            with(() -> (sv[], s_b[]), sv => 21, s_b => :violet)
        ) == (21, :violet)

        @test @inferred(
            with(() -> (s_a[], sv[]), s_a => 21, sv => 33)
        ) == (21, 33)

        @test @inferred((
            () -> @with s_a => 21 s_b => :violet (s_a[], s_b[])
        )()) == (21, :violet)

        @test @inferred((
            () -> @with sv => 21 s_b => :violet (sv[], s_b[])
        )()) == (21, :violet)

        @test @inferred((
            () -> @with s_a => 21 sv => 33 (s_a[], sv[])
        )()) == (21, 33)
    end

    s_union = ScopedSetting{Union{Int,Float64}}(42)

    @testset "union types" begin
        @test s_union[] == 42

        @with s_union => 11 begin
            @test s_union[] == 11
            @test s_union[] isa Int
        end

        @with s_union => 5.0 begin
            @test s_union[] == 5.0
            @test s_union[] isa Float64
        end
    end

    @testset "types containing Nothing" begin
        s_n = ScopedSetting{Union{Nothing,Int}}(0)

        @test s_n[] == 0
        s_n[] = nothing
        @test s_n[] === nothing
        s_n[] = default_value
        @test s_n[] == 0

        with(s_n => nothing) do
            @test s_n[] === nothing
        end
        @test s_n[] == 0
    end

    @testset "types admitting the markers" begin
        s_any = ScopedSetting{Any}(42)
        s_any[] = 11
        with(s_any => default_value) do
            # Scoped values are stored out-of-band, so the marker is just a value here:
            @test s_any[] === default_value
            @test_throws ErrorException s_any[] = 0
        end
        @test s_any[] == 11
        s_any[] = default_value
        @test s_any[] == 42
    end

    @testset "pairs with abstract key type" begin
        s = ScopedSetting(42)
        pair = first(Dict{ScopedSetting,Any}(s => 21))
        @test with(() -> s[], pair) == 21
    end
end
