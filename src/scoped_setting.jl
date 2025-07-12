# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).


"""
    struct ScopedSetting{T,F<:Base.Callable}

A scoped setting, similar to a `ScopedValues.ScopedValue`, but with a mutable
global default value.

Constructors:

```julia
ScopedSetting(x_default)
ScopedSetting(f_default::Function)
ScopedSetting(ctor_default::Type)
ScopedSetting{T,F}(f_default::F) where {T,F<:Base.Callable}
```

Example:

```julia
s = ScopedSetting(42)

s[] == 42

s[] = 11
s[] == 11

s[] = nothing
s[] == 42

with(s => 21) do
    s[] == 21
end

s[] == 42
```
"""
struct ScopedSetting{T,F<:Base.Callable}
    _scopedval::ScopedValue{Union{Nothing,T}}
    _f_default::F
    _ref_override_val::Ref{Union{Nothing,T}}
    _ref_override_lock::ReentrantLock

    # To avoid Aqua unbound type parameter error (default ctor can't infer T if _scopedval and _ref_override_val are nothing):
    function ScopedSetting{T,F}(scopedval::ScopedValue{Union{Nothing,T}}, _f_default::F, _ref_override_val::Ref{Union{Nothing,T}}, _ref_override_lock::ReentrantLock) where {T,F<:Base.Callable}
        return new{T,F}(scopedval, _f_default, _ref_override_val, _ref_override_lock)
    end
end
export ScopedSetting


function ScopedSetting{T,F}(f_default::F) where {T,F<:Base.Callable}
    return ScopedSetting{T,F}(
        ScopedValue{Union{Nothing,T}}(nothing),
        f_default,
        Ref{Union{Nothing,T}}(nothing),
        ReentrantLock()
    )
end

ScopedSetting(x_default::T) where T = ScopedSetting{T,Returns{T}}(Returns(x_default))

function ScopedSetting(f_default::F) where {F<:Function}
    T = Core.Compiler.return_type(f_default, Tuple{})
    ScopedSetting{T,F}(f_default)
end

ScopedSetting(ctor_default::Type{T}) where T = ScopedSetting{T,Type{T}}(ctor_default)

function Base.getindex(s::ScopedSetting{T}) where T
    x_scoped = s._scopedval[]
    if isnothing(x_scoped)
        @lock s._ref_override_lock begin
            x_override = s._ref_override_val[]
            if isnothing(x_override)
                return s._f_default()::T
            else
                return x_override::T
            end
        end
    else
        return x_scoped::T
    end    
end

function Base.setindex!(s::ScopedSetting, new_default)
    if isnothing(s._scopedval[])
        @lock s._ref_override_lock s._ref_override_val[] = new_default
    else
        error("Can't set ScopedSetting default value when inside of a non-default scope/context")
    end
    return new_default
end


_AnyScoped = Union{<:ScopedSetting,<:ScopedValue}

_get_scopedvalue(v::ScopedValue) = v
_get_scopedvalue(s::ScopedSetting) = s._scopedval

_scopedvalue_pair(pair::Pair{<:ScopedValue}) = pair
_scopedvalue_pair(pair::Pair{<:ScopedSetting}) = _get_scopedvalue(pair.first) => pair.second


@inline function ScopedValues.with(f, pair::Pair{<:_AnyScoped}, rest::Pair{<:_AnyScoped}...)
    with(f, _scopedvalue_pair(pair), map(_scopedvalue_pair, rest)...)
end


# Implements support for @with, modified versions of ScopedValues.Scope methods for ScopedValue:

@inline function ScopedValues.Scope(parent::Union{Nothing, Scope}, key::ScopedSetting{T}, value) where T
    return Scope(parent, key._scopedval, value)
end


@static if isdefined(Base, :ScopedValues)
    # Specialize Base.ScopedValues.Scope methods:

    @inline function ScopedValues.Scope(scope, pair::Pair{<:ScopedSetting})
        return Scope(scope, pair...)
    end

    function ScopedValues.Scope(scope, pair1::Pair{<:_AnyScoped}, pair2::Pair{<:_AnyScoped}, pairs::Pair{<:_AnyScoped}...)
        # Unroll this loop through recursion to make sure that
        # our compiler optimization support works
        return Scope(Scope(scope, pair1...), pair2, pairs...)
    end
else
    # Specialize ScopedValues.Scope methods (Julia < v1.11):

    function Scope(scope, pairs::Pair{<:_AnyScoped}...)
        for pair in pairs
            scope = Scope(scope, pair...)
        end
        return scope::Scope
    end
end
