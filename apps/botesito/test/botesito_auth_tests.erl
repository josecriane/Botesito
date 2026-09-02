-module(botesito_auth_tests).

-include_lib("eunit/include/eunit.hrl").

authenticate_test_() ->
    {setup, fun setup/0, fun cleanup/1, [
        {"a matching bearer token is accepted", fun accepts_matching_token/0},
        {"the scheme is matched case-insensitively", fun accepts_any_case_scheme/0},
        {"the header name is matched case-insensitively", fun accepts_any_case_header/0},
        {"a wrong token is rejected", fun rejects_wrong_token/0},
        {"a missing header is rejected", fun rejects_missing_header/0},
        {"a non-bearer scheme is rejected", fun rejects_other_scheme/0}
    ]}.

setup() ->
    Previous = application:get_env(botesito, api_token),
    ok = application:set_env(botesito, api_token, <<"s3cret">>),
    Previous.

cleanup(undefined) ->
    application:unset_env(botesito, api_token);
cleanup({ok, Value}) ->
    application:set_env(botesito, api_token, Value).

accepts_matching_token() ->
    ?assertEqual(ok, auth([{<<"authorization">>, <<"Bearer s3cret">>}])).

accepts_any_case_scheme() ->
    ?assertEqual(ok, auth([{<<"authorization">>, <<"bearer s3cret">>}])).

accepts_any_case_header() ->
    ?assertEqual(ok, auth([{<<"Authorization">>, <<"Bearer s3cret">>}])).

rejects_wrong_token() ->
    ?assertEqual(
        {error, unauthorized}, auth([{<<"authorization">>, <<"Bearer nope">>}])
    ).

rejects_missing_header() ->
    ?assertEqual({error, unauthorized}, auth([])).

rejects_other_scheme() ->
    ?assertEqual(
        {error, unauthorized}, auth([{<<"authorization">>, <<"Basic s3cret">>}])
    ).

unconfigured_token_test() ->
    Previous = application:get_env(botesito, api_token),
    ok = application:set_env(botesito, api_token, undefined),
    try
        ?assertEqual(
            {error, unauthorized}, auth([{<<"authorization">>, <<"Bearer s3cret">>}])
        )
    after
        cleanup(Previous)
    end.

auth(Headers) ->
    botesito_auth:authenticate(#{headers => Headers}).
