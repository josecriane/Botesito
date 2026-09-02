-module(botesito_app).

-behaviour(application).

-export([start/2, stop/1]).

-export([
    send_message/2,
    telegram_status/0
]).

start(_StartType, _StartArgs) ->
    ok = botesito_config:load(),
    botesito_sup:start_link().

stop(_State) ->
    ok.

-spec send_message(binary(), telegram:send_opts()) ->
    {ok, telegram:message()} | {error, term()}.
send_message(Text, Opts) when is_binary(Text) ->
    case telegram:available() of
        false -> {error, unconfigured};
        true -> telegram:send_message(Text, Opts)
    end.

-spec telegram_status() -> ok | unconfigured.
telegram_status() ->
    case telegram:available() of
        true -> ok;
        false -> unconfigured
    end.
