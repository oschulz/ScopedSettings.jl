# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

"""
    ScopedSettings

Scoped settings in Julia, building on ScopedValues.
"""
module ScopedSettings

using Base: UUID
using Compat: @compat

using Preferences: load_preference, main_uuid

@static if isdefined(Base, :ScopedValues)
    using Base.ScopedValues: ScopedValues, ScopedValue, Scope, with, @with
else
    # Julia < v1.11, use ScopedValues.jl:
    using ScopedValues: ScopedValues, ScopedValue, Scope, with, @with
end

export with, @with

include("get_preference.jl")
include("unchanged.jl")
include("scoped_setting.jl")

end # module
