# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

"""
    struct GetPreference{T} <: Function

Represents a function that retrieves an a preference via Julia Preferences.jl,
environment variables and a default value.

Constructors:

```julia
GetPreference(m::Module, pref_name::AbstractString, x_default; f_conv = nothing)
GetPreference(m::Module, pref_name::AbstractString, env_name::AbstractString, x_default; f_conv = nothing)
GetPreference{T}(m::Module, pref_name::AbstractString, env_name::AbstractString, x_default; f_conv = nothing)
```

If `env_name` is not specified, it defaults to the uppercase module name,
followed by `JL_`, followed by the uppercase preference name.

Example:

```julia
f_getpref = GetPreference(SomePackage, "some_pref", 42)

delete!(ENV, "SOMEPACKAGEJL_SOME_PREF")
f_getpref() == 42

ENV["SOMEPACKAGEJL_SOME_PREF"] = "11"
f_getpref() == 11
```

The return value of `f_getpref()` depends on the `LocalPreferences.toml` files
(if any) in your `LOAD_PATH` that have entries like

```toml
[SomePackage]
some_pref = 22
```

(see the [Preferences](https://github.com/JuliaPackaging/Preferences.jl) docs)
and the environment variable `SOMEPACKAGEJL_SOME_PREF` (if set).
Environment variables take precedence over preferences. If neither is set,
`f_getpref()` returns the default value (`42` in this case).

By default, `GetPreference{T}` function objects use
[`ScopedSettings.convert_preference`](@ref) to convert preferences TOML values
and environment variable string values to `T`. Via `f_conv = my_f_conv` you
can set a custom conversion function `my_f_conv(pref_or_env_var_value)::T`.
"""
struct GetPreference{T,F} <: Function
    _module_name::String
    _module_uuid::UUID
    _pref_name::String
    _env_name::String
    _x_default::T
    _f_conv::F
end
export GetPreference


function GetPreference{T}(m::Module, pref_name::AbstractString, env_name::AbstractString, x_default; f_conv = nothing) where T
    module_name = string(nameof(m))
    module_uuid = _get_module_uuid(m)
    new_x_default = convert(T, x_default)
    F = Core.Typeof(f_conv)
    GetPreference{T,F}(module_name, module_uuid, pref_name, env_name, new_x_default, f_conv)
end

function GetPreference(m::Module, pref_name::AbstractString, env_name::AbstractString, x_default; f_conv = nothing)
    new_x_default = _preproc_default_val(x_default)
    T = typeof(new_x_default)
    GetPreference{T}(m, pref_name, env_name, new_x_default; f_conv = f_conv)
end

function GetPreference(m::Module, pref_name::AbstractString, x_default::T; f_conv = nothing) where T
    module_name = string(nameof(m))
    env_name = uppercase(module_name) * "JL_" * uppercase(pref_name)
    GetPreference(m, pref_name, env_name, x_default; f_conv = f_conv)
end


function Base.show(io::IO, mime::MIME"text/plain", @nospecialize(f::GetPreference{T})) where T
    print(io, "GetPreference{", T, "}(")
    print(io, f._module_name, ", ")
    show(io, f._pref_name); print(io, ", ")
    show(io, f._env_name); print(io, ", ")
    show(io, f._x_default)
    if !isnothing(f._f_conv)
        print(io, ", f_conv = ")
        show(io, mime, f._f_conv)
    end
    print(io, ")")
end

Base.show(io::IO, @nospecialize(f::GetPreference)) = show(io, MIME("text/plain"), f)


function (f::GetPreference{T})() where T
    f_conv = f._f_conv
    if haskey(ENV, f._env_name)
        envval = ENV[f._env_name]
        if !isnothing(f._f_conv)
            return f_conv(envval)::T
        else
            return convert_preference(T, envval)::T
        end
    else
        prefval = load_preference(f._module_uuid, f._pref_name)
        if !isnothing(prefval)
            if !isnothing(f._f_conv)
                return f_conv(prefval)::T
            else
                return convert_preference(T, prefval)::T
            end
        else
            return f._x_default
        end
    end
end


_preproc_default_val(x) = x
_preproc_default_val(x::AbstractString) = convert(String, x)


"""
    ScopedSettings.convert_preference(::Type{T}, toml_value)
    ScopedSettings.convert_preference(::Type{T}, env_string::AbstractString)

Convert a Preferences.jl TOML value or an environment variable string to the
specified type `T`.

`convert_preference` is used by [`GetPreference{T}`](@ref) function objects
and is open to specialization for custom types `T`.
"""
function convert_preference end
@compat public convert_preference

convert_preference(::Type{T}, s::AbstractString) where T <: AbstractString = convert(T, s)::T
convert_preference(::Type{T}, s::AbstractString) where T = parse(T, s)::T
convert_preference(::Type{<:Symbol}, s::AbstractString) = Symbol(s)::Symbol
convert_preference(::Type{T}, x) where T = convert(T, x)::T


# Code originally from `Preferences.get_uuid`, modified here:

const _uuid_cache = IdDict{Module, Base.UUID}()

function _get_module_uuid(m::Module)
    if haskey(_uuid_cache, m)
        return _uuid_cache[m]
    elseif parentmodule(m) !== m
        # traverse up the module hierarchy while caching the results
        return _uuid_cache[m] = _get_module_uuid(parentmodule(m))
    elseif m === Main && main_uuid[] !== nothing
        # load a specified package configuration for running script
        return main_uuid[]::UUID
    else
        # get package UUID
        uuid = Base.PkgId(m).uuid
        if uuid === nothing
            throw(ArgumentError("Module $(m) does not correspond to a loaded package!"))
        end
        return _uuid_cache[m] = uuid
    end
end
