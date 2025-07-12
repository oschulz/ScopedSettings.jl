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

    # Test type stability when f_conv is a type ctor:
    f_getpref = GetPreference(ScopedSettings, "some_pref", :green, f_conv = Symbol)
    @test f_getpref isa GetPreference{Symbol, Type{Symbol}}
    ENV["SCOPEDSETTINGSJL_SOME_PREF"] = "blue"
    @test @inferred(f_getpref()) == :blue
end
