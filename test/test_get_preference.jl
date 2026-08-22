# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

using ScopedSettings
using Test

import Pkg
import Preferences

@testset "get_preference" begin
    toml_type(x) = x
    toml_type(x::Symbol) = String(x)

    for vals in [
        ("foo", "bar", "baz"),
        ("foo", view("foobarbaz", 4:6), view("foobarbaz", 7:9)),
        (view("foobar", 1:3), "bar", "baz"),
        (:foo, :bar, :baz),
        (true, false, true),
        (42, 11, 37),
        (4.2, 1.1e-12, 3.7e9),
    ]
        x_default, x_pref, x_env = vals
        @test @inferred(GetPreference(ScopedSettings, "some_pref", x_default)) isa GetPreference
        f_getpref = GetPreference(ScopedSettings, "some_pref", x_default)

        delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
        @test @inferred(f_getpref()) == x_default

        ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "$x_env"
        @test @inferred(f_getpref()) == x_env

        delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
        mktempdir(;prefix = "ScopedSettings-runtests_") do tmpdir
            push!(LOAD_PATH, tmpdir)
            try
                current_prj = Pkg.project().path
                Pkg.activate(tmpdir)
                try
                    Preferences.set_preferences!(ScopedSettings, "some_pref" => toml_type(x_pref))
                finally
                    Pkg.activate(current_prj)
                end
                @test @inferred(f_getpref()) == x_pref

                ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "$x_env"
                @test @inferred(f_getpref()) == x_env                
            finally
                pop!(LOAD_PATH)
            end
        end
    end

    f_getpref = GetPreference(ScopedSettings, "some_pref", 42, f_conv = s -> 2 * parse(Int, s))
    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "11"
    @test @inferred(f_getpref()) == 22

    # f_conv results are converted, so they need not match T exactly (e.g. TOML
    # integers are Int64 even where Int is Int32):
    f_getpref = GetPreference{Int32}(ScopedSettings, "some_pref", Int32(42), f_conv = s -> 2 * parse(Int64, s))
    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "11"
    @test @inferred(f_getpref()) === Int32(22)

    # Test type stability when f_conv is a type ctor:
    f_getpref = GetPreference(ScopedSettings, "some_pref", :green, f_conv = Symbol)
    @test f_getpref isa GetPreference{Symbol, Type{Symbol}}
    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "blue"
    @test @inferred(f_getpref()) == :blue

    # Explicit environment variable name:
    f_getpref = GetPreference(ScopedSettings, "some_pref", 42, env_name = "SOME_ENV_VAR")
    @test f_getpref isa GetPreference{Int, Nothing}
    delete!(ENV, "SOME_ENV_VAR")
    @test @inferred(f_getpref()) == 42
    ENV["SOME_ENV_VAR"] = "11"
    @test @inferred(f_getpref()) == 11
    delete!(ENV, "SOME_ENV_VAR")

    # Explicit result type:
    f_getpref = GetPreference{Float64}(ScopedSettings, "some_pref", 42, env_name = "SOME_ENV_VAR")
    @test f_getpref isa GetPreference{Float64, Nothing}
    @test @inferred(f_getpref()) === 42.0

    # Explicit result type with derived env var name:
    f_getpref = GetPreference{Float64}(ScopedSettings, "some_pref", 42)
    @test f_getpref isa GetPreference{Float64, Nothing}
    @test f_getpref._env_name == "SCOPEDSETTINGSJL_SOME_PREF"
    delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
    @test @inferred(f_getpref()) === 42.0

    # f_conv must also be applied to preference values:
    delete!(ENV, "SCOPEDSETTINGSJL_SOME_PREF")
    mktempdir(;prefix = "ScopedSettings-runtests_") do tmpdir
        push!(LOAD_PATH, tmpdir)
        try
            current_prj = Pkg.project().path
            Pkg.activate(tmpdir)
            try
                Preferences.set_preferences!(ScopedSettings, "some_pref" => 11)
            finally
                Pkg.activate(current_prj)
            end
            f_getpref = GetPreference(ScopedSettings, "some_pref", 42, f_conv = x -> 2 * x)
            @test @inferred(f_getpref()) == 22
        finally
            pop!(LOAD_PATH)
        end
    end

    @testset "convert_preference" begin
        @test ScopedSettings.convert_preference(String, view("foobar", 1:3)) == "foo"
        @test ScopedSettings.convert_preference(Int, "42") == 42
        @test ScopedSettings.convert_preference(Symbol, "foo") === :foo
        @test ScopedSettings.convert_preference(Float64, 42) === 42.0
    end

    @testset "show" begin
        f_getpref = GetPreference(ScopedSettings, "some_pref", 42)
        @test repr(f_getpref) == "GetPreference{$Int}(ScopedSettings, \"some_pref\", 42, env_name = \"SCOPEDSETTINGSJL_SOME_PREF\")"
        @test repr("text/plain", f_getpref) == repr(f_getpref)

        f_getpref = GetPreference(ScopedSettings, "some_pref", :green, f_conv = Symbol)
        @test repr(f_getpref) == "GetPreference{Symbol}(ScopedSettings, \"some_pref\", :green, env_name = \"SCOPEDSETTINGSJL_SOME_PREF\", f_conv = Symbol)"
    end

    @testset "module UUID resolution" begin
        f_sub = GetPreference(Pkg.Types, "some_pref", 42)
        @test f_sub._module_uuid == Base.PkgId(Pkg).uuid
        @test f_sub._module_name == "Pkg"
        @test f_sub._env_name == "PKGJL_SOME_PREF"

        # Anonymous modules resolve via their parentmodule chain to Main,
        # which has no package UUID here:
        @test_throws ArgumentError GetPreference(Module(:NoPkgModule), "some_pref", 42)

        prev_main_uuid = Preferences.main_uuid[]
        try
            Preferences.main_uuid[] = Base.PkgId(ScopedSettings).uuid
            f_main = GetPreference(Main, "some_pref", 42)
            @test f_main._module_uuid == Base.PkgId(ScopedSettings).uuid
        finally
            Preferences.main_uuid[] = prev_main_uuid
        end
    end
end
