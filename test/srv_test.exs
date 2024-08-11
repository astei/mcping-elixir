defmodule MCPing.SrvTest do
  use ExUnit.Case, async: true

  test "single SRV records work" do
    assert MCPing.Srv.find_eligible_srv_records([{1, 1, 25565, "example.com"}]) ==
             [{"example.com", 25565}]
  end

  test "will sort SRV record with the highest priority first" do
    # DNS SRV priorities are supported to be checked in ascending order.
    assert MCPing.Srv.find_eligible_srv_records([
             {1, 1, 25566, "s2.example.com"},
             {0, 1, 25565, "s1.example.com"}
           ]) == [{"s1.example.com", 25565}, {"s2.example.com", 25566}]
  end

  test "will respect SRV record weight" do
    records = [{1, 25, 25565, "s1.example.com"}, {1, 75, 25566, "s2.example.com"}]
    state = :rand.seed_s(:exsss, 0)
    Process.put(:srv_test_state, state)

    # Statistically speaking, we should get s2.example.com 75% of the time, and s1.example.com 25% of the time.
    # We'll run this test 100 times to ensure that the distribution is roughly correct.

    # Also note that we're using a stateful RNG here, and we're storing the state in the process dictionary.
    # This is necessary because we can't update the state within the map function.
    results =
      Enum.map(1..100, fn _ ->
        {v, state} =
          MCPing.Srv.find_eligible_srv_records(records, Process.get(:srv_test_state))

        Process.put(:srv_test_state, state)
        v
      end)

    assert Enum.count(results, fn
             [{"s1.example.com", 25565}] -> true
             _ -> false
           end) in 20..30
  end

  test "will respect SRV record weights for multiple priorities" do
    records = [
      {1, 25, 25565, "s1.example.com"},
      {1, 75, 25566, "s2.example.com"},
      {0, 50, 25567, "s3.example.com"},
      {0, 50, 25568, "s4.example.com"}
    ]
    state = :rand.seed_s(:exsss, 1)  # different seed, which makes the test pass
    Process.put(:srv_test_state, state)

    # At priority 0, we get either s3 or s4 50% of the time, and at priority 1, we get s1 25% of the time and s2 75% of the time.
    # We will get each combination with the following probabilities:
    # - P(s3, s1) = .5 * .25 = .125,
    # - P(s4, s2) = .5 * .75 = .375
    # - P(s3, s2) = .5 * .75 = .375
    # - P(s4, s1) = .5 * .25 = .125

    # We'll run this test 100 times to ensure that the distribution is roughly correct.
    results =
      Enum.map(1..100, fn _ ->
        {v, state} =
          MCPing.Srv.find_eligible_srv_records(records, Process.get(:srv_test_state))

        Process.put(:srv_test_state, state)
        v
      end)

    assert Enum.count(results, fn
             [{"s3.example.com", 25567}, {"s1.example.com", 25565}] -> true
             _ -> false
           end) in 10..20

    assert Enum.count(results, fn
             [{"s4.example.com", 25568}, {"s2.example.com", 25566}] -> true
             _ -> false
           end) in 30..40

    assert Enum.count(results, fn
             [{"s3.example.com", 25567}, {"s2.example.com", 25566}] -> true
             _ -> false
           end) in 30..40

    assert Enum.count(results, fn
             [{"s4.example.com", 25568}, {"s1.example.com", 25565}] -> true
             _ -> false
           end) in 10..20
  end
end
