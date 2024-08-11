defmodule MCPing do
  alias MCPing.Protocol
  alias MCPing.Srv

  @default_protocol_version -1
  @default_timeout :timer.seconds(3)

  @moduledoc """
  A utility library to ping other Minecraft: Java Edition servers.
  """

  defp maybe_resolve_minecraft_srv(hostname, specified_port, timeout) do
    case Srv.resolve_srv_record("minecraft", "tcp", hostname, timeout) do
      {:ok, {hostname, port}} -> {hostname, port}
      _ -> {to_charlist(hostname), specified_port}
    end
  end

  defp ping_server(conn, options) do
    with :ok <- Protocol.send_handshake_and_status_request_packet(conn, options.virtual_host, options.port, options.protocol_version),
         {:ok, ping} <- Protocol.read_status_response_packet(conn, options.timeout),
         pinged_at <- :erlang.monotonic_time(:millisecond),
         :ok <- Protocol.send_status_ping_packet(conn, pinged_at),
         :ok <- Protocol.discard_server_ping_response_packet(conn, options.timeout),
         ponged_at <- :erlang.monotonic_time(:millisecond) do
      {:ok, Map.put(ping, "ping", ponged_at - pinged_at)}
    end
  end

  @doc """
  Pings a remote Minecraft: Java Edition server.

  ## Parameters

    * `address` - The address of the server to ping.
    * `port` - The port of the server to ping. Defaults to 25565.
    * `options` - A keyword list of options:
      * `:timeout` - The timeout in milliseconds for the connection. Defaults to 3000.
      * `:protocol_version` - The protocol version to use for the handshake. Defaults to `-1`, whose behavior varies by server. Vanilla servers will typically respond with the version they use, Velocity will assume the latest version of Minecraft, and other servers may have different behavior.
      * `:virtual_host` - The virtual host to use for the handshake. Defaults to the specified `address`.

  ## Examples

       iex> MCPing.get_info("mc.hypixel.net")
       {:ok, ...}

  """
  def get_info(address, port \\ 25565, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout)
    {resolved_address, resolved_port} = maybe_resolve_minecraft_srv(address, port, timeout)

    resolved_options = format_ping_options(address, resolved_port, options)

    case :gen_tcp.connect(resolved_address, resolved_port, [:binary, active: false, send_timeout: timeout, nodelay: true], timeout) do
      {:ok, conn} ->
        try do
          case ping_server(conn, resolved_options) do
            {:ok, ping} -> {:ok, ping}
            {:error, reason} -> {:error, reason}
          end
        after
          :gen_tcp.close(conn)
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_ping_options(original_address, port, options) do
    Enum.into(options, %{
      # these options can be overridden
      timeout: @default_timeout,
      protocol_version: @default_protocol_version,
      virtual_host: original_address,

      # these... shouldn't be
      original_address: original_address,
      port: port
    })
  end
end
