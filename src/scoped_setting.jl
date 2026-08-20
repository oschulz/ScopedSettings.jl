# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).


"""
    struct DefaultValue

The type of [`default_value`](@ref).
"""
struct DefaultValue end
@compat public DefaultValue

"""
    default_value

A sentinel value that indicates that a default value is to be used.

Assigning `default_value` in settings, constructors and keyword arguments
selects the default, complementing `nothing` ("no value") and `missing`
("value unknown"). Assigning it to a [`ScopedSetting`](@ref) removes its
global override and restores its original default behavior.
"""
const default_value = DefaultValue()
export default_value


# Probe Base directly: on Julia v1.10 the ScopedValues binding is the
# ScopedValues.jl package, which must not trigger the native path even if a
# future release adds an AbstractScopedValue for parity:
const _HAS_ABSTRACT_SCOPED_VALUE = isdefined(Base, :ScopedValues) && isdefined(Base.ScopedValues, :AbstractScopedValue)

@static if _HAS_ABSTRACT_SCOPED_VALUE
    mutable struct ScopedSetting{T,F<:Base.Callable} <: ScopedValues.AbstractScopedValue{T}
        const _f_default::F
        @atomic _override::Union{DefaultValue,T}

        function ScopedSetting{T,F}(f_default::F) where {T,F<:Base.Callable}
            return new{T,F}(f_default, DefaultValue())
        end
    end
else
    # Julia < v1.13, no AbstractScopedValue to subtype, wrap a ScopedValue:
    mutable struct ScopedSetting{T,F<:Base.Callable}
        const _f_default::F
        @atomic _override::Union{DefaultValue,T}
        const _scopedval::ScopedValue{T}

        function ScopedSetting{T,F}(f_default::F) where {T,F<:Base.Callable}
            return new{T,F}(f_default, DefaultValue(), ScopedValue{T}())
        end
    end
end

"""
    mutable struct ScopedSetting{T,F<:Base.Callable}

A scoped setting, similar to a `ScopedValues.ScopedValue`, but with a mutable
global default value.

Constructors:

```julia
ScopedSetting(x_default)
ScopedSetting(f_default::Function)
ScopedSetting(ctor_default::Type)
ScopedSetting{T}(x_default)
ScopedSetting{T}(f_default::Function)
ScopedSetting{T}(ctor_default::Type)
ScopedSetting{T,F}(f_default::F) where {T,F<:Base.Callable}
```

`Function` and `Type` arguments are always taken as default-value factories.
To use a callable or type as the default value itself, wrap it in `Returns`.

Example:

```jldoctest
julia> s = ScopedSetting(42)
ScopedSetting{Int64}(42)

julia> s[]
42

julia> s[] = 11;

julia> s[]
11

julia> s[] = default_value;

julia> s[]
42

julia> with(s => 21) do
           s[]
       end
21

julia> s[]
42
```

[`default_value`](@ref) and [`ScopedSettings.unchanged`](@ref ScopedSettings.unchanged) are
the only reserved values, so `T` may include `Nothing`, e.g.
`ScopedSetting{Union{Nothing,Int}}(0)`.

`isassigned` and `ScopedValues.get` are supported on all Julia versions. On
Julia >= v1.13, `ScopedSetting` is a subtype of
`Base.ScopedValues.AbstractScopedValue`.
"""
ScopedSetting

export ScopedSetting

function ScopedSetting{T}(x_default) where T
    f_default = Returns(convert(T, x_default))
    return ScopedSetting{T,typeof(f_default)}(f_default)
end

ScopedSetting{T}(f_default::F) where {T,F<:Function} = ScopedSetting{T,F}(f_default)

ScopedSetting{T}(ctor_default::Type{U}) where {T,U} = ScopedSetting{T,Type{U}}(ctor_default)

ScopedSetting(x_default::T) where T = ScopedSetting{T}(x_default)

function ScopedSetting(f_default::F) where {F<:Function}
    T = Base.promote_op(f_default)
    ScopedSetting{T,F}(f_default)
end

ScopedSetting(ctor_default::Type{T}) where T = ScopedSetting{T,Type{T}}(ctor_default)


Base.eltype(::Type{<:ScopedSetting{T}}) where T = T

function _default_value(s::ScopedSetting{T}) where T
    x_override = @atomic s._override
    return x_override isa DefaultValue ? convert(T, s._f_default())::T : x_override
end

function Base.setindex!(s::ScopedSetting{T}, x) where T
    _check_not_shadowed(s)
    @atomic s._override = convert(T, x)
    return s
end

function Base.setindex!(s::ScopedSetting, ::DefaultValue)
    _check_not_shadowed(s)
    @atomic s._override = DefaultValue()
    return s
end

# A pure no-op, so it is safe even where real assignments would be rejected:
Base.setindex!(s::ScopedSetting, ::Unchanged) = s

function _check_not_shadowed(s::ScopedSetting)
    if _is_shadowed(s)
        error("Can't set the global default value of a ScopedSetting inside a scope that sets it")
    end
    return nothing
end

function Base.show(io::IO, s::ScopedSetting{T}) where T
    print(io, ScopedSetting, '{', T, "}(")
    try
        show(IOContext(io, :typeinfo => T), s[])
    catch
        print(io, "<error>")
    end
    print(io, ')')
end


@static if _HAS_ABSTRACT_SCOPED_VALUE
    # hasdefault/getdefault are the (not yet public) AbstractScopedValue
    # extension interface, with/@with/getindex/get/isassigned then come
    # from ScopedValues directly:

    ScopedValues.hasdefault(::ScopedSetting) = true
    ScopedValues.getdefault(s::ScopedSetting) = _default_value(s)

    function _is_shadowed(s::ScopedSetting)
        scope = Core.current_scope()::Union{Nothing,Scope}
        return scope !== nothing && haskey(scope.values, s)
    end
else
    # Julia < v1.13:

    function Base.getindex(s::ScopedSetting{T}) where T
        maybe_scoped = ScopedValues.get(s._scopedval)
        return maybe_scoped isa Nothing ? _default_value(s) : something(maybe_scoped)::T
    end

    # Same API as inherited from AbstractScopedValue on Julia >= v1.13:
    Base.isassigned(::ScopedSetting) = true
    ScopedValues.get(s::ScopedSetting{T}) where T = Some{T}(s[])

    _is_shadowed(s::ScopedSetting) = isassigned(s._scopedval)

    const _AnyScoped = Union{ScopedSetting,ScopedValue}

    _scopedvalue_pair(pair::Pair{<:ScopedValue}) = pair
    _scopedvalue_pair(pair::Pair{<:ScopedSetting}) = pair.first._scopedval => convert(eltype(pair.first), pair.second)

    # Implements support for @with, modified versions of ScopedValues.Scope methods for ScopedValue:

    @inline function ScopedValues.Scope(parent::Union{Nothing, Scope}, key::ScopedSetting{T}, value) where T
        return Scope(parent, key._scopedval, convert(T, value))
    end

    @static if isdefined(Base, :ScopedValues)
        # Julia v1.11/v1.12, specialize Base.ScopedValues methods:

        function ScopedValues.with(f, pair::Pair{<:_AnyScoped}, rest::Pair{<:_AnyScoped}...)
            @with(_scopedvalue_pair(pair), map(_scopedvalue_pair, rest)..., f())
        end

        @inline function ScopedValues.Scope(scope, pair::Pair{<:ScopedSetting})
            return Scope(scope, pair...)
        end

        function ScopedValues.Scope(scope, pair1::Pair{<:_AnyScoped}, pair2::Pair{<:_AnyScoped}, pairs::Pair{<:_AnyScoped}...)
            # Unroll this loop through recursion to make sure that
            # our compiler optimization support works
            return Scope(Scope(scope, pair1...), pair2, pairs...)
        end
    else
        # Julia v1.10, specialize ScopedValues.jl methods:

        @inline function ScopedValues.with(f, pair::Pair{<:_AnyScoped}, rest::Pair{<:_AnyScoped}...)
            with(f, _scopedvalue_pair(pair), map(_scopedvalue_pair, rest)...)
        end

        function Scope(scope, pairs::Pair{<:_AnyScoped}...)
            for pair in pairs
                scope = Scope(scope, pair...)
            end
            return scope::Scope
        end
    end
end
