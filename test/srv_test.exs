defmodule MCPing.SrvTest do
  use ExUnit.Case, async: true

  test "single SRV records work" do
    assert MCPing.Srv.find_first_eligible_srv_record([{1, 1, 25565, "example.com"}]) == {"example.com", 25565}
  end

  test "will pick the SRV record with the lowest priority first" do
    assert MCPing.Srv.find_first_eligible_srv_record([{1, 1, 25566, "s2.example.com"}, {0, 1, 25565, "s1.example.com"}]) == {"s1.example.com", 25565}
  end

  test "will respect SRV record weight" do
    records = [{1, 25, 25565, "s1.example.com"}, {1, 75, 25566, "s2.example.com"}]
    state = :rand.seed_s(:exsss, 0)
    Process.put(:srv_test_state, state)

    # Statistically speaking, we should get s2.example.com 75% of the time, and s1.example.com 25% of the time.
    # We'll run this test 100 times to ensure that the distribution is roughly correct.

    # Also note that we're using a stateful RNG here, and we're storing the state in the process dictionary.
    # This is necessary because we can't update the state within the map function.
    results = Enum.map(1..100, fn _ ->
      {v, state} = MCPing.Srv.find_first_eligible_srv_record(records, Process.get(:srv_test_state))
      Process.put(:srv_test_state, state)
      v
    end)

    assert Enum.count(results, fn {"s1.example.com", 25565} -> true; _ -> false end) in 20..30
  end
end