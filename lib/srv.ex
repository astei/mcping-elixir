defmodule MCPing.Srv do
  @moduledoc """
  Functions for resolving SRV records. SRV records are used to provide a way to map a service name and protocol to a hostname and port.
  This module is used as a part of MCPing for optionally resolving the SRV record for a Minecraft server, but it is general enough to
  be used for any service that uses SRV records, such as XMPP or SIP.
  """

  @doc """
  Resolves a single SRV record for a given service, protocol, and hostname. Returns the first SRV record with the
  highest priority. If no SRV records are found, returns an error.

  ## Examples

      iex> MCPing.Srv.resolve_srv_record("minecraft", "tcp", "hypixel.net", 5000)
      {:ok, {~c"mc.hypixel.net", 25565}}

      iex> MCPing.Srv.resolve_srv_record("minecraft", "tcp", "mc.example.com", 5000)
      {:error, :nxdomain}
  """
  def resolve_srv_record(service, protocol, hostname, timeout) do
    case lookup_server(service, protocol, hostname, timeout) do
      {:ok, entries} -> {:ok, hd(entries)}
      {:error, err} -> {:error, err}
    end
  end

  @spec lookup_server(binary(), binary(), binary(), :infinity | non_neg_integer()) ::
          {:error, atom()}
  @doc """
  Resolves all SRV records for a given service, protocol, and hostname. Returns a list of all SRV records found,
  sorted by priority order. If a record with a given priority has multiple records with different weights, the
  records will be randomly selected based on their weight.

  If no SRV records are found, returns `:error`.

  ## Examples

      iex> MCPing.Srv.lookup_server("minecraft", "tcp", "hypixel.net", 5000)
      {:ok, [{~c"mc.hypixel.net", 25565}]}
  """
  def lookup_server(service, protocol, hostname, timeout) do
    minecraft_srv = to_charlist("_" <> service <> "._" <> protocol <> "." <> hostname)

    case :inet_res.getbyname(minecraft_srv, :srv, timeout) do
      {:ok, {:hostent, _, _, :srv, _, records}} -> {:ok, find_eligible_srv_records(records)}
      {:error, err} -> {:error, err}
    end
  end

  @doc false
  def find_eligible_srv_records(records) when is_list(records) and length(records) == 1 do
    {_, _, port, host} = hd(records)
    [{host, port}]
  end

  @doc false
  def find_eligible_srv_records(records) when is_list(records) do
    {t, _} = find_eligible_srv_records(records, :rand.seed_s(:default))
    t
  end

  @doc false
  def find_eligible_srv_records(records, rand_state) do
    picked_by_priority =
      records
      |> Enum.sort_by(fn {priority, weight, _, _} -> {priority, -weight} end)
      |> Enum.group_by(fn {priority, _, _, _} -> priority end, fn {_, weight, port, host} ->
        {weight, port, host}
      end)

    # Since Erlang maps are unordered, we need to sort the keys to ensure that we always pick the same order of priorities.
    sorted_priorities = picked_by_priority
      |> Map.keys()
      |> Enum.sort()

    {selected_record_by_priority_reversed, rand_state} = Enum.reduce(sorted_priorities, {[], rand_state}, fn
      priority, {entries, rand_state} ->
        {entry, rand_state} = pick_weighted_random_s(picked_by_priority[priority], rand_state)
        {[entry | entries], rand_state}
    end)

    {Enum.reverse(selected_record_by_priority_reversed), rand_state}
  end

  defp pick_weighted_random_s(entries, rand_state) do
    reweighted = Enum.scan(entries, fn
      (element, acc) when is_nil(acc) -> element
      ({weight, port, host}, acc) -> {elem(acc, 0) + weight, port, host}
     end)

    total_weight = List.last(reweighted) |> elem(0)
    {random_weight, next_state} = :rand.uniform_s(total_weight, rand_state)

    {_, port, host} = Enum.find(reweighted, fn {weight, _, _} -> random_weight <= weight end)
    {{host, port}, next_state}
  end
end
