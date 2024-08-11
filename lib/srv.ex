defmodule MCPing.Srv do
  @moduledoc """
  Functions for resolving SRV records.
  """

  @doc """
  Resolves a SRV record for a given service, protocol, and hostname.

  ## Examples

      iex> MCPing.Srv.resolve_srv_record("minecraft", "tcp", "hypixel.net", 5000)
      {~c"mc.hypixel.net", 25565}
  """
  def resolve_srv_record(service, protocol, hostname, timeout) do
    minecraft_srv = to_charlist("_" <> service <> "._" <> protocol <> "." <> hostname)

    case :inet_res.getbyname(minecraft_srv, :srv, timeout) do
      {:ok, {:hostent, _, _, :srv, _, records}} -> {:ok, find_first_eligible_srv_record(records)}
      _ -> nil
    end
  end

  @doc false
  def find_first_eligible_srv_record(records) when is_list(records) and length(records) == 1 do
    {_, _, port, host} = hd(records)
    {host, port}
  end

  @doc false
  def find_first_eligible_srv_record(records) when is_list(records) do
    {t, _} = find_first_eligible_srv_record(records, :rand.seed_s(:default))
    t
  end

  @doc false
  def find_first_eligible_srv_record(records, rand_state) do
    picked_by_priority =
      records
      |> Enum.sort_by(fn {priority, weight, _, _} -> {priority, -weight} end)
      |> Enum.group_by(fn {priority, _, _, _} -> priority end, fn {_, weight, port, host} ->
        {weight, port, host}
      end)

    max_priority = Map.keys(picked_by_priority) |> Enum.min()
    weighted = Map.get(picked_by_priority, max_priority)

    pick_weighted_random_s(weighted, rand_state)
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
