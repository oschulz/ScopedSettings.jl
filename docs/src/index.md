# ScopedSettings.jl

ScopedSettings builds on [ScopedValues](https://github.com/vchuravy/ScopedValues.jl) (equivalent to `Base.ScopedValues` for Julia >= v1.11) to implement scoped settings.

A [`ScopedSetting{T}`](@ref), like a `ScopedValue{T}`, can be set to different values in different scopes. But unlike a `ScopedValue`, the global default value of a `ScopedSetting` can either be a value or can be computed on the fly, and can be mutated via a global override. ScopedSettings integrates with [Preferences](https://github.com/JuliaPackaging/Preferences.jl) to base `ScopedValue` default values on preferences and environment variables.

So while a scoped setting

```julia
using ScopedSettings

some_setting = ScopedSetting(42)
some_setting isa ScopedSetting{Int}
```

is accessed like a `ScopedValue`

```julia
some_setting[] == 42
```

it's global default value can be overridden

```julia
some_setting[] = 11
some_setting[] == 11
```

and can also be restored to the original default value

```julia
some_setting[] = nothing
some_setting[] == 42
```

The global default can also be function (without arguments):

```julia
other_setting = ScopedSetting(()->rand())
[other_setting[], other_setting[], other_setting[]] # random values

other_setting[] = 1.2 # override
other_setting[] == 1.2 # no more random values
```

Like with a `ScopedValue`, scoped settings can be set to different values
for different scopes:

```julia
@with some_setting => 33 other_setting => 5.2 begin
    # Within this scope, we have
    some_setting[] == 33 && other_setting[] == 5.2
end

with(some_setting => 33, other_setting => 5.2) do
    # Within this scope, we have
    some_setting[] == 33 && other_setting[] == 5.2
end

# Globally we still have
some_setting[] == 42
other_setting[] == 1.2
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
setting_foo[] == either_envvar_or_preference_value_or_green

@with setting_foo => 11 setting_bar => :blue begin
    # Different values within this scope
    setting_foo[] == 11 && setting_bar[] == :blue
end

# Original values outside of the scope
setting_foo[] == either_envvar_or_preference_value_or_42
setting_foo[] == either_envvar_or_preference_value_or_green
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
