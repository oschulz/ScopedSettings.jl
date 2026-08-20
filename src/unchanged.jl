# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

"""
    struct Unchanged

The type of [`unchanged`](@ref).
"""
struct Unchanged end
@compat public Unchanged

"""
    unchanged

A sentinel value that indicates that a current value is to be kept.

Assigning `unchanged` in settings, constructors and keyword arguments is a
no-op that keeps the current value, complementing `nothing` ("no value") and
`missing` ("value unknown"). In contrast, assigning
[`default_value`](@ref) to a [`ScopedSetting`](@ref) actively restores its
default behavior.
"""
const unchanged = Unchanged()
@compat public unchanged
