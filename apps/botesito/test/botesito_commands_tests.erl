-module(botesito_commands_tests).

-include_lib("eunit/include/eunit.hrl").

parse_help_test() ->
    ?assertEqual(help, botesito_commands:parse(<<"/help">>)),
    ?assertEqual(help, botesito_commands:parse(<<"/start">>)).

parse_status_test() ->
    ?assertEqual(status, botesito_commands:parse(<<"/status">>)),
    ?assertEqual(status, botesito_commands:parse(<<"  /status  ">>)),
    ?assertEqual(alerts, botesito_commands:parse(<<"/alerts">>)).

parse_strips_bot_mention_test() ->
    ?assertEqual(status, botesito_commands:parse(<<"/status@botesito_bot">>)).

parse_logs_test() ->
    ?assertEqual({logs, <<"jellyfin">>}, botesito_commands:parse(<<"/logs jellyfin">>)),
    ?assertEqual({usage, <<"/logs <app>">>}, botesito_commands:parse(<<"/logs">>)).

parse_restart_test() ->
    ?assertEqual({restart, <<"paperless">>}, botesito_commands:parse(<<"/restart paperless">>)),
    ?assertEqual({usage, <<"/restart <app>">>}, botesito_commands:parse(<<"/restart a b">>)).

parse_silence_test() ->
    ?assertEqual(
        {silence, <<"KubeMemoryOvercommit">>, 7200},
        botesito_commands:parse(<<"/silence KubeMemoryOvercommit 2h">>)
    ),
    ?assertMatch({usage, _}, botesito_commands:parse(<<"/silence OnlyAlert">>)),
    ?assertMatch({usage, _}, botesito_commands:parse(<<"/silence Alert forever">>)).

parse_unknown_test() ->
    ?assertEqual({unknown, <<"/deploy">>}, botesito_commands:parse(<<"/deploy">>)).

parse_ignores_chatter_test() ->
    ?assertEqual(ignore, botesito_commands:parse(<<"buenas">>)),
    ?assertEqual(ignore, botesito_commands:parse(<<>>)),
    ?assertEqual(ignore, botesito_commands:parse(<<"   ">>)),
    ?assertEqual(ignore, botesito_commands:parse(undefined)).

parse_duration_units_test() ->
    ?assertEqual({ok, 30}, botesito_commands:parse_duration(<<"30s">>)),
    ?assertEqual({ok, 1800}, botesito_commands:parse_duration(<<"30m">>)),
    ?assertEqual({ok, 7200}, botesito_commands:parse_duration(<<"2h">>)),
    ?assertEqual({ok, 86400}, botesito_commands:parse_duration(<<"1d">>)).

parse_duration_rejects_test() ->
    ?assertEqual(error, botesito_commands:parse_duration(<<"2">>)),
    ?assertEqual(error, botesito_commands:parse_duration(<<"2w">>)),
    ?assertEqual(error, botesito_commands:parse_duration(<<"0h">>)),
    ?assertEqual(error, botesito_commands:parse_duration(<<"-3h">>)),
    ?assertEqual(error, botesito_commands:parse_duration(<<"h">>)).

handle_ignores_chatter_test() ->
    ?assertEqual(ignore, botesito_commands:handle(<<"hola">>)).

handle_help_mentions_every_command_test() ->
    Help = botesito_commands:handle(<<"/help">>),
    lists:foreach(
        fun(Command) -> ?assertNotEqual(nomatch, binary:match(Help, Command)) end,
        [<<"/status">>, <<"/alerts">>, <<"/logs">>, <<"/restart">>, <<"/silence">>]
    ).

handle_usage_test() ->
    ?assertEqual(<<"usage: /logs <app>">>, botesito_commands:handle(<<"/logs">>)).

handle_unknown_test() ->
    ?assertEqual(
        <<"/deploy is not a command, try /help">>, botesito_commands:handle(<<"/deploy">>)
    ).
