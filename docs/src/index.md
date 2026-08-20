# ScopedSettings.jl

ScopedSettings builds on [ScopedValues](https://github.com/vchuravy/ScopedValues.jl) (equivalent to `Base.ScopedValues` for Julia >= v1.11) to implement scoped settings.

A [`ScopedSetting{T}`](@ref), like a `ScopedValue{T}`, can be set to different values in different scopes. But unlike a `ScopedValue`, the global default value of a `ScopedSetting` can either be a value or can be computed on the fly, and can be mutated via a global override. ScopedSettings integrates with [Preferences](https://github.com/JuliaPackaging/Preferences.jl) to base `ScopedSetting` default values on preferences and environment variables.

So while a scoped setting

```jldoctest usage
julia> using ScopedSettings

julia> some_setting = ScopedSetting(42)
ScopedSetting{Int64}(42)
```

is accessed like a `ScopedValue`

```jldoctest usage
julia> some_setting[]
42
```

its global default value can be overridden

```jldoctest usage
julia> some_setting[] = 11;

julia> some_setting[]
11
```

and can also be restored to the original default value

```jldoctest usage
julia> some_setting[] = default_value;

julia> some_setting[]
42
```

[`default_value`](@ref) is the only reserved value, so setting types may
include `Nothing`, e.g. `ScopedSetting{Union{Nothing,Int}}(0)`.

The global default can also be a function (without arguments) that is
evaluated on each access, until it is overridden:

```jldoctest usage
julia> other_setting = ScopedSetting(() -> rand());

julia> other_setting[] isa Float64
true

julia> other_setting[] = 1.2;

julia> other_setting[]
1.2
```

Like with a `ScopedValue`, scoped settings can be set to different values
for different scopes:

```jldoctest usage
julia> @with some_setting => 33 other_setting => 5.2 begin
           (some_setting[], other_setting[])
       end
(33, 5.2)

julia> with(some_setting => 33, other_setting => 5.2) do
           (some_setting[], other_setting[])
       end
(33, 5.2)

julia> (some_setting[], other_setting[])  # globally unchanged
(42, 1.2)
```

ScopedSettings re-exports `ScopedValues.@with` and `ScopedValues.with(...)`. You can mix `ScopedSetting` and `ScopedValue` objects in `@with` expressions
and `with(...)` calls.

To base `ScopedSetting` default values on
[package preferences](https://github.com/JuliaPackaging/Preferences.jl) and
environment variables, ScopedSettings provides [`GetPreference{T}`](@ref)
function objects:

```julia
setting_foo = ScopedSetting(GetPreference(SomePackage, "foo", 42))
setting_bar = ScopedSetting(GetPreference(SomePackage, "bar", :green))

setting_foo[] == either_envvar_or_preference_value_or_42
setting_bar[] == either_envvar_or_preference_value_or_green

@with setting_foo => 11 setting_bar => :blue begin
    # Different values within this scope
    setting_foo[] == 11 && setting_bar[] == :blue
end

# Original values outside of the scope
setting_foo[] == either_envvar_or_preference_value_or_42
setting_bar[] == either_envvar_or_preference_value_or_green
```

In the global scope, the value of `setting_foo[]` will depend on the `LocalPreferences.toml` files (if any) in your `LOAD_PATH` that have entries like

```toml
[SomePackage]
foo = 33
bar = "turquoise"
```

and environment variables like `SOMEPACKAGEJL_FOO` and `SOMEPACKAGEJL_BAR` (environment variables take precedence over preferences).

`GetPreference` can also be used standalone, without `ScopedSetting`. The direct return values of `GetPreference` function objects are scope-independent, of course:

```julia
get_foo = GetPreference(SomePackage, "foo", 42)
get_foo() == either_envvar_or_preference_value_or_42
```
