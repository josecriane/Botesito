-module(botesito_callback).

-export([
    healthz/1,
    receive_alerts/1,
    send_message/1
]).

healthz(_Request) ->
    Telegram = botesito_app:telegram_status(),
    {200, [], #{
        <<"status">> => health_status(Telegram),
        <<"telegram">> => atom_to_binary(Telegram)
    }}.

health_status(ok) -> <<"ok">>;
health_status(unconfigured) -> <<"degraded">>.

send_message(#{body := Body} = Request) ->
    authenticated(Request, fun() ->
        deliver(maps:get(<<"text">>, Body), send_opts(Body))
    end).

receive_alerts(#{body := Body} = Request) ->
    authenticated(Request, fun() ->
        deliver(botesito_alert_manager:format(Body), #{})
    end).

authenticated(Request, Deliver) ->
    case botesito_auth:authenticate(Request) of
        {error, unauthorized} -> unauthorized();
        ok -> Deliver()
    end.

deliver(Text, Opts) ->
    case botesito_app:send_message(Text, Opts) of
        {ok, Result} ->
            {201, [], render(Result, Text)};
        {error, unconfigured} ->
            unavailable();
        {error, Reason} ->
            upstream_error(Reason)
    end.

send_opts(Body) ->
    lists:foldl(
        fun({Key, Field}, Acc) ->
            case maps:get(Field, Body, undefined) of
                undefined -> Acc;
                Value -> Acc#{Key => Value}
            end
        end,
        #{},
        [
            {parse_mode, <<"parse_mode">>},
            {silent, <<"silent">>},
            {preview_links, <<"preview_links">>}
        ]
    ).

render(Result, SentText) ->
    #{
        <<"message_id">> => maps:get(<<"message_id">>, Result),
        <<"chat_id">> => maps:get(<<"id">>, maps:get(<<"chat">>, Result, #{}), null),
        <<"sent_at">> => rfc3339(maps:get(<<"date">>, Result, undefined)),
        <<"text">> => maps:get(<<"text">>, Result, SentText)
    }.

rfc3339(undefined) ->
    rfc3339(erlang:system_time(second));
rfc3339(Seconds) when is_integer(Seconds) ->
    list_to_binary(
        calendar:system_time_to_rfc3339(Seconds, [{offset, "Z"}, {unit, second}])
    ).

unauthorized() ->
    {401, [], #{
        <<"code">> => <<"unauthorized">>,
        <<"message">> => <<"Authentication required">>
    }}.

unavailable() ->
    {503, [], #{
        <<"code">> => <<"unconfigured">>,
        <<"message">> => <<"Telegram bot token or chat id is not configured">>
    }}.

upstream_error(Reason) ->
    {502, [], #{
        <<"code">> => <<"upstream_error">>,
        <<"message">> => iolist_to_binary(io_lib:format("~p", [Reason]))
    }}.
