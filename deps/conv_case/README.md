# ConvCase
[![Hex.pm: version](https://img.shields.io/hexpm/v/conv_case.svg?style=flat-square)](https://hex.pm/packages/conv_case)
[![GitHub: CI status](https://img.shields.io/github/workflow/status/hrzndhrn/conv_case/CI?style=flat-square)](https://github.com/hrzndhrn/conv_case/actions)
[![Coveralls: coverage](https://img.shields.io/coveralls/github/hrzndhrn/conv_case?style=flat-square)](https://coveralls.io/github/hrzndhrn/conv_case)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://github.com/hrzndhrn/conv_case/blob/main/LICENSE.md)

A library to convert strings, atoms and map keys between `camelCase`,
`snake_case` and `kebab-case`.

## Installation

The package can be installed by adding `conv_case` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:conv_case, "~> 0.1.0"}
  ]
end
```

Documentation can be found at https://hexdocs.pm/conv_case.

## Alternatives

If this package fits not your requirements then take a look here:

  * [Macro.camelize/1](https://hexdocs.pm/elixir/Macro.html#camelize/1) and
    [Macro.underscore/1](https://hexdocs.pm/elixir/Macro.html#underscore/1)
  * [ReCase](https://github.com/sobolevn/recase) helps you to convert a string
    from any case to any case.
  * [ProperCase](https://github.com/johnnyji/proper_case) an Elixir library that
    converts keys in maps between snake_case and camel_case.
