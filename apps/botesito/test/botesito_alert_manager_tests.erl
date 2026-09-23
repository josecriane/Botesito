-module(botesito_alert_manager_tests).

-include_lib("eunit/include/eunit.hrl").

format_test_() ->
    [
        {"a firing alert renders name, summary and context", fun renders_firing_alert/0},
        {"the status is uppercased", fun uppercases_status/0},
        {"a single alert is counted in singular", fun counts_singular/0},
        {"several alerts are counted in plural", fun counts_plural/0},
        {"the severity prefixes the alert name", fun prefixes_severity/0},
        {"a missing severity leaves the name alone", fun omits_missing_severity/0},
        {"the description is used when there is no summary", fun falls_back_to_description/0},
        {"only known context labels are rendered", fun filters_context_labels/0},
        {"an alert without labels still renders", fun renders_bare_alert/0},
        {"a long group is truncated below the Telegram limit", fun truncates_long_group/0},
        {"truncatedAlerts is added to the dropped count", fun counts_upstream_truncation/0},
        {"a single oversized alert is clipped, not dropped", fun clips_oversized_alert/0},
        {"an empty payload still produces a header", fun renders_empty_payload/0}
    ].

renders_firing_alert() ->
    Text = botesito_alert_manager:format(webhook(<<"firing">>, [alert()])),
    ?assertEqual(
        <<
            "FIRING 1 alert\n\n"
            "[critical] KubePodCrashLooping\n"
            "Pod extra/stirling-pdf is restarting\n"
            "namespace=extra pod=stirling-pdf-0"
        >>,
        Text
    ).

uppercases_status() ->
    Text = botesito_alert_manager:format(webhook(<<"resolved">>, [alert()])),
    ?assertMatch(<<"RESOLVED 1 alert\n\n", _/binary>>, Text).

counts_singular() ->
    ?assertMatch(
        <<"FIRING 1 alert\n", _/binary>>, botesito_alert_manager:format(webhook([alert()]))
    ).

counts_plural() ->
    Text = botesito_alert_manager:format(webhook([alert(), alert()])),
    ?assertMatch(<<"FIRING 2 alerts\n", _/binary>>, Text).

prefixes_severity() ->
    Text = botesito_alert_manager:format(webhook([labelled(#{<<"severity">> => <<"warning">>})])),
    ?assert(contains(Text, <<"[warning] Whatever">>)).

omits_missing_severity() ->
    Text = botesito_alert_manager:format(webhook([labelled(#{})])),
    ?assert(contains(Text, <<"\n\nWhatever">>)),
    ?assertNot(contains(Text, <<"[">>)).

falls_back_to_description() ->
    Alert = #{
        <<"labels">> => #{<<"alertname">> => <<"Whatever">>},
        <<"annotations">> => #{<<"description">> => <<"the long story">>}
    },
    ?assert(contains(botesito_alert_manager:format(webhook([Alert])), <<"the long story">>)).

filters_context_labels() ->
    Alert = #{
        <<"labels">> => #{
            <<"alertname">> => <<"Whatever">>,
            <<"namespace">> => <<"monitoring">>,
            <<"prometheus">> => <<"monitoring/kps">>
        }
    },
    Text = botesito_alert_manager:format(webhook([Alert])),
    ?assert(contains(Text, <<"namespace=monitoring">>)),
    ?assertNot(contains(Text, <<"prometheus=">>)).

renders_bare_alert() ->
    ?assert(contains(botesito_alert_manager:format(webhook([#{}])), <<"unknown">>)).

truncates_long_group() ->
    Text = botesito_alert_manager:format(webhook([alert() || _ <- lists:seq(1, 200)])),
    ?assert(byte_size(Text) =< 4096),
    ?assert(contains(Text, <<" more">>)).

counts_upstream_truncation() ->
    Body = (webhook([alert()]))#{<<"truncatedAlerts">> => 7},
    ?assert(contains(botesito_alert_manager:format(Body), <<"+7 more">>)).

clips_oversized_alert() ->
    Long = binary:copy(<<"x">>, 8000),
    Alert = #{
        <<"labels">> => #{<<"alertname">> => Long},
        <<"annotations">> => #{<<"summary">> => Long}
    },
    Text = botesito_alert_manager:format(webhook([Alert])),
    ?assert(byte_size(Text) =< 4096),
    ?assert(contains(Text, <<"xxx">>)).

renders_empty_payload() ->
    ?assertEqual(<<"FIRING 0 alerts">>, botesito_alert_manager:format(#{})).

webhook(Alerts) ->
    webhook(<<"firing">>, Alerts).

webhook(Status, Alerts) ->
    #{<<"status">> => Status, <<"alerts">> => Alerts}.

alert() ->
    #{
        <<"status">> => <<"firing">>,
        <<"labels">> => #{
            <<"alertname">> => <<"KubePodCrashLooping">>,
            <<"severity">> => <<"critical">>,
            <<"namespace">> => <<"extra">>,
            <<"pod">> => <<"stirling-pdf-0">>
        },
        <<"annotations">> => #{<<"summary">> => <<"Pod extra/stirling-pdf is restarting">>}
    }.

labelled(Extra) ->
    #{<<"labels">> => maps:merge(#{<<"alertname">> => <<"Whatever">>}, Extra)}.

contains(Haystack, Needle) ->
    binary:match(Haystack, Needle) =/= nomatch.
