# ScopedSettings.jl

[![Documentation for stable version](https://img.shields.io/badge/docs-stable-blue.svg)](https://oschulz.github.io/ScopedSettings.jl/stable)
[![Documentation for development version](https://img.shields.io/badge/docs-dev-blue.svg)](https://oschulz.github.io/ScopedSettings.jl/dev)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![Build Status](https://github.com/oschulz/ScopedSettings.jl/workflows/CI/badge.svg)](https://github.com/oschulz/ScopedSettings.jl/actions/workflows/CI.yml)
[![Codecov](https://codecov.io/gh/oschulz/ScopedSettings.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/oschulz/ScopedSettings.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

ScopedSettings builds on
[ScopedValues](https://github.com/vchuravy/ScopedValues.jl) (equivalent to
`Base.ScopedValues` for Julia >= v1.11) to implement scoped settings.

A `ScopedSetting`, like a `ScopedValue`, can be set to different values in
different scopes. But unlike a `ScopedValue`, the global default value of a
`ScopedSetting` can either be a value or can be computed on the fly, and can
be mutated via a global override. ScopedSettings integrates with
[Preferences](https://github.com/JuliaPackaging/Preferences.jl)
to base `ScopedValue` default values on preferences and environment variables.

 See the package documentation for more details:

* [Documentation for stable version](https://oschulz.github.io/ScopedSettings.jl/stable)
* [Documentation for development version](https://oschulz.github.io/ScopedSettings.jl/dev)
