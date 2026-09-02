-module(botesito_auth).

-export([authenticate/1]).

-spec authenticate(erf:request()) -> ok | {error, unauthorized}.
authenticate(Request) ->
    case api_token() of
        undefined ->
            {error, unauthorized};
        Expected ->
            case bearer(Request) of
                undefined -> {error, unauthorized};
                Given -> compare(Given, Expected)
            end
    end.

compare(Given, Expected) ->
    case crypto:hash_equals(crypto:hash(sha256, Given), crypto:hash(sha256, Expected)) of
        true -> ok;
        false -> {error, unauthorized}
    end.

bearer(Request) ->
    case header(<<"authorization">>, maps:get(headers, Request, [])) of
        undefined ->
            undefined;
        Value ->
            case string:lowercase(Value) of
                <<"bearer ", _/binary>> ->
                    <<_:7/binary, Token/binary>> = Value,
                    string:trim(Token);
                _ ->
                    undefined
            end
    end.

header(Name, Headers) when is_list(Headers) ->
    Lower = string:lowercase(Name),
    Match = [V || {K, V} <- Headers, is_binary(K), string:lowercase(K) =:= Lower],
    case Match of
        [] -> undefined;
        [V | _] -> V
    end;
header(_Name, _Headers) ->
    undefined.

api_token() ->
    case application:get_env(botesito, api_token, undefined) of
        undefined -> undefined;
        <<>> -> undefined;
        Bin when is_binary(Bin) -> Bin;
        L when is_list(L) -> list_to_binary(L)
    end.
