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
    picked_by_priority = records
                         |> Enum.sort_by(fn {priority, weight, _, _} -> {priority, -weight} end)
                         |> Enum.group_by(fn {priority, _, _, _} -> priority end, fn {_, weight, port, host} -> {weight, port, host} end)

    max_priority = Map.keys(picked_by_priority) |> Enum.min()
    weighted = Map.get(picked_by_priority, max_priority)

    pick_weighted_random_s(weighted, rand_state)
  end

  defp hd_or_zero([]), do: 0
  defp hd_or_zero(list), do: hd(list)

  defp pick_weighted_random_s(entries, rand_state) do
    # Accumulate the weights of the entries. We'll need to do this to "normalize" the weights in the provided list.
    total_weights = Enum.reduce(entries, [], fn {weight, _, _}, acc -> acc ++ [weight + hd_or_zero(acc)] end)
    total_weight = List.last(total_weights)
    reweighted = Enum.zip_with(entries, total_weights, fn {_, port, host}, total_weight -> {total_weight, port, host} end)

    {random_weight, next_state} = :rand.uniform_s(total_weight, rand_state)

    {_, port, host} = Enum.find(reweighted, fn {weight, _, _} -> random_weight <= weight end)

    {{host, port}, next_state}
  end
end