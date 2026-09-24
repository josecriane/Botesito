-module(botesito_followup_tests).

-include_lib("eunit/include/eunit.hrl").

format_settled_rollout_test() ->
    Rollout = #{desired => 1, updated => 1, ready => 1},
    ?assertEqual(
        <<"jellyfin rolled, 1/1 ready">>,
        botesito_followup:format_rollout(<<"jellyfin">>, Rollout, true)
    ).

format_unsettled_rollout_test() ->
    Rollout = #{desired => 2, updated => 2, ready => 1},
    ?assertEqual(
        <<"paperless is still rolling, 1/2 ready">>,
        botesito_followup:format_rollout(<<"paperless">>, Rollout, false)
    ).

format_rollout_with_nothing_ready_test() ->
    Rollout = #{desired => 1, updated => 0, ready => 0},
    ?assertEqual(
        <<"botesito is still rolling, 0/1 ready">>,
        botesito_followup:format_rollout(<<"botesito">>, Rollout, false)
    ).
