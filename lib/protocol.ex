defmodule MCPing.Protocol do
  import Bitwise

  #
  # Minecraft data types
  #

  @spec pack_varint(integer) :: nonempty_binary
  defp pack_varint(num) do
    # We need to reinterpret the provided number as an signed integer. Minecraft uses a
    # variant of Protocol Buffer VarInts where numbers above 2**31-1 are considered signed,
    # versus ZigZag encoding. Elixir doesn't provide a natural way to coerce a signed-to-unsigned
    # conversion, so this is what we get.
    <<e::unsigned-integer-32>> = <<num::signed-integer-32>>
    Varint.LEB128.encode(e)
  end

  defp pack_data(str) do
    pack_varint(byte_size(str)) <> str
  end

  defp unpack_varint_from_conn(conn, timeout) do
    unpack_varint_from_conn(conn, 0, 0, timeout)
  end

  defp unpack_varint_from_conn(conn, d, n, timeout) do
    with {:ok, <<b>>} = :gen_tcp.recv(conn, 1, timeout) do
      a = bor(d, (b &&& 0x7F) <<< (7 * n))

      cond do
        (b &&& 0x80) == 0 ->
          {:ok, a}

        n > 4 ->
          raise("suspicious varint size (tried to read more than 5 bytes)")

        true ->
          unpack_varint_from_conn(conn, a, n + 1, timeout)
      end
    end
  end

  #
  # Key packets
  #
  defp construct_handshake_packet(address, port, protocol_version) do
    # Handshake
    # Next state: status
    <<0x00>> <>
      pack_varint(protocol_version) <>
      pack_data(address) <>
      <<port::signed-16>> <>
      <<0x01>>
  end

  defp construct_status_request_packet() do
    <<0x00>>
  end

  def send_handshake_and_status_request_packet(conn, address, port, protocol_version) do
    contents = [
      construct_handshake_packet(address, port, protocol_version),
      construct_status_request_packet()
    ]
    |> Enum.map(&pack_data/1)
    |> Enum.join()

    :gen_tcp.send(conn, contents)
  end

  def construct_status_ping_packet(random) do
    <<0x01>> <> <<random::big-signed-64>>
  end

  def send_status_ping_packet(conn, random) do
    :gen_tcp.send(conn, random |> construct_status_ping_packet() |> pack_data())
  end

  def read_minecraft_framed_packet(conn, timeout) do
    with {:ok, packet_len} = unpack_varint_from_conn(conn, timeout) do
      :gen_tcp.recv(conn, packet_len, timeout)
    end
  end

  def read_status_response_packet(conn, timeout) do
    with {:ok, raw_packet} = read_minecraft_framed_packet(conn, timeout),
         {0, packet_contents} = Varint.LEB128.decode(raw_packet),
         {_, server_ping_json} = Varint.LEB128.decode(packet_contents) do
      Jason.decode(server_ping_json)
    end
  end

  def discard_server_ping_response_packet(conn, timeout) do
    with {:ok, raw_packet} = read_minecraft_framed_packet(conn, timeout),
         {0x01, _} = Varint.LEB128.decode(raw_packet) do
      :ok
    end
  end
end
