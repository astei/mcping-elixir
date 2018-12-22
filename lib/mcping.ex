defmodule MCPing do
  require Jason
  use Bitwise

  @mc_protocol_version 340

  @moduledoc """
  A utility library to ping other Minecraft: Java Edition servers.
  """

  defp pack_varint(num) do
    pack_varint(num, <<>>)
  end

  defp pack_varint(num, buf) do
    b = num &&& 0x7F
    d = num >>> 7

    cond do
      d > 0 ->
        pack_varint(d, buf <> <<bor(b, 0x80)>>)

      d == 0 ->
        buf <> <<b>>
    end
  end

  defp pack_port(port) do
    <<port::size(16)>>
  end

  defp pack_data(str) do
    pack_varint(byte_size(str)) <> str
  end

  defp construct_handshake_packet(address, port) do
    pack_varint(0) <>
      pack_varint(@mc_protocol_version) <> pack_data(address) <> pack_port(port) <> pack_varint(1)
  end

  defp unpack_varint(conn, timeout) do
    unpack_varint(conn, 0, 0, timeout)
  end

  defp unpack_varint(conn, d, n, timeout) do
    read = :gen_tcp.recv(conn, 1, timeout)

    case read do
      {:ok, read} ->
        b = :binary.at(read, 0)
        a = bor(d, (b &&& 0x7F) <<< (7 * n))

        cond do
          (b &&& 0x80) == 0 ->
            {:ok, a}

          n > 4 ->
            raise("suspicious varint size (tried to read more than 5 bytes)")

          true ->
            unpack_varint(conn, a, n + 1, timeout)
        end

      error ->
        error
    end
  end

  @doc """
  Pings a remote Minecraft: Java Edition server.

  ## Examples

       iex> MCPing.get_info("mc.hypixel.net")
       {:ok, ...}

  """
  def get_info(address, port \\ 25565, timeout \\ 3000) do
    # gen_tcp uses Erlang strings (charlists), convert this beforehand
    address_chars = to_charlist(address)
    result = :gen_tcp.connect(address_chars, port, [:binary, active: false], timeout)

    case result do
      {:ok, conn} ->
        try do
          handshake = construct_handshake_packet(address, port) |> pack_data
          :ok = :gen_tcp.send(conn, handshake)
          :ok = :gen_tcp.send(conn, pack_data(<<0>>))

          # Ignore the returned packet size
          {:ok, _} = unpack_varint(conn, timeout)
          # Ignore the packet ID
          {:ok, _} = unpack_varint(conn, timeout)
          {:ok, json_size} = unpack_varint(conn, timeout)
          {:ok, json_packet} = :gen_tcp.recv(conn, json_size, timeout)

          # Convert from iolist to binary, and then to a map
          decoded = :erlang.iolist_to_binary(json_packet) |> Jason.decode!()
          {:ok, decoded}
        after
          :gen_tcp.close(conn)
        end

      error ->
        error
    end
  end
end
