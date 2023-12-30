# MCPing

This is a simple library that you can use to ping _Minecraft: Java Edition_ servers
using Elixir. It's built primarily on Erlang's `gen_tcp` support, and the response
JSON is deserialized automatically with [Jason](https://github.com/michalmuskala/jason).

## How to Use It

It's pretty easy. Here's how you might use it:

```elixir
{:ok, response} = MCPing.get_info("mc.hypixel.net")
```

`get_info` takes three parameters, of which only the `address` is required.
The return value is a tuple:

* `{:ok, status}` - we were able to contact the server successfully.
* `{:error, reason}` - we were unable to contact the server (the `reason` is usually from
  the underlying `gen_tcp` client).

The docs can be found at [https://hexdocs.pm/mcping](https://hexdocs.pm/mcping).

## Installation

This package can be installed by adding `mcping` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mcping, "~> 0.2.0"}
  ]
end
```