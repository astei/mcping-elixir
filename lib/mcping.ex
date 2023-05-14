defmodule MCPing do
  require Jason

  import Bitwise

  @default_protocol_version -1

  @moduledoc """
  A utility library to ping other Minecraft: Java Edition servers.
  """

  @spec pack_varint(integer) :: nonempty_binary
  defp pack_varint(num) do
    # We need to reintepret the provided number as an signed integer. Minecraft uses a
    # variant of Protocol Buffer VarInts where numbers above 2**31-1 are considered signed,
    # versus ZigZag encoding. Elixir doesn't provide a natural way to coerce a signed-to-unsigned
    # conversion, so this is what we get.
    <<e::unsigned-integer-32>> = <<num::signed-integer-32>>
    Varint.LEB128.encode(e)
  end

  defp pack_port(port) do
    <<port::signed-16>>
  end

  defp pack_data(str) do
    pack_varint(byte_size(str)) <> str
  end

  defp construct_handshake_packet(address, port, protocol_version) do
    # Handshake
    # Next state: status
    <<0x00>> <>
      pack_varint(protocol_version) <>
      pack_data(address) <>
      pack_port(port) <>
      <<0x01>>
  end

  defp unpack_varint(conn, timeout) do
    unpack_varint(conn, 0, 0, timeout)
  end

  defp unpack_varint(conn, d, n, timeout) do
    with {:ok, <<b>>} = :gen_tcp.recv(conn, 1, timeout) do
      a = bor(d, (b &&& 0x7F) <<< (7 * n))
      cond do
        (b &&& 0x80) == 0 ->
          {:ok, a}

        n > 4 ->
          raise("suspicious varint size (tried to read more than 5 bytes)")

        true ->
          unpack_varint(conn, a, n + 1, timeout)
      end
    end
  end

  @doc """
  Pings a remote Minecraft: Java Edition server.

  ## Examples

       iex> MCPing.get_info("mc.hypixel.net")
       {:ok, ...}

  """
  def get_info(address, port \\ 25565, options \\ []) do
    # gen_tcp uses Erlang strings (charlists), convert this beforehand
    address_chars = to_charlist(address)

    timeout = Keyword.get(options, :timeout, 3000)
    protocol_version = Keyword.get(options, :protocol_version, @default_protocol_version)

    with {:ok, conn} <- :gen_tcp.connect(address_chars, port, [:binary, active: false], timeout),
         # Send the handshake and the ping packet in one send
         handshake <- construct_handshake_packet(address, port, protocol_version) |> pack_data,
         :ok <- :gen_tcp.send(conn, handshake <> <<0x01, 0x0>>),

         # Ignore the returned packet size for the ping. Assert that the packet ID is expected,
         # and then read the ping data and deserialize the server ping as JSON.
         {:ok, _} <- unpack_varint(conn, timeout),
         {:ok, 0x00} <- unpack_varint(conn, timeout),
         {:ok, json_size} <- unpack_varint(conn, timeout),
         {:ok, raw_ping} <- :gen_tcp.recv(conn, json_size, timeout),
         {:ok, json_ping} <- raw_ping |> :erlang.iolist_to_binary() |> Jason.decode(),

         # Send a ping packet
         pinged_at <- :os.system_time(:millisecond),
         :ok <- :gen_tcp.send(conn, <<0x09, 0x01>> <> <<pinged_at::big-signed-64>>),
         {:ok, 0x09} <- unpack_varint(conn, timeout),
         {:ok, 0x01} <- unpack_varint(conn, timeout),
         {:ok, _} <- :gen_tcp.recv(conn, 8, timeout),
         ponged_at <- :os.system_time(:millisecond),
         :ok <- :gen_tcp.close(conn) do
      {:ok, Map.put(json_ping, "ping", ponged_at - pinged_at)}
    end
  end
end
