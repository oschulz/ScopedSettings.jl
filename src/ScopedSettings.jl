# This file is a part of ScopedSettings.jl, licensed under the MIT License (MIT).

"""
    ScopedSettings

Scoped settings in Julia, building on ScopedValues.
"""
module ScopedSettings

using Base: UUID
using Compat: @compat

using Preferences: load_preference, main_uuid

import ScopedValues
using ScopedValues: ScopedValue, Scope, with, @with

export with, @with

include("get_preference.jl")
include("scoped_setting.jl")

end # module
