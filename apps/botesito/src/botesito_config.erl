-module(botesito_config).

-export([load/0]).

-define(OVERRIDES, [
    {"BOTESITO_PORT", botesito, port, port},
    {"BOTESITO_API_TOKEN", botesito, api_token, binary},
    {"BOTESITO_SPEC_PATH", botesito, spec_path, binary},
    {"TELEGRAM_BOT_TOKEN", telegram, bot_token, binary},
    {"TELEGRAM_CHAT_ID", telegram, chat_id, chat_id}
]).

-spec load() -> ok.
load() ->
    ok = load_file(os:getenv("BOTESITO_CONFIG")),
    lists:foreach(fun apply_override/1, ?OVERRIDES).

load_file(false) ->
    ok;
load_file("") ->
    ok;
load_file(Path) ->
    case conf:load_file(Path) of
        ok -> ok;
        {error, Reason} -> erlang:error({bad_config_file, Path, Reason})
    end.

apply_override({Var, App, Key, Type}) ->
    case os:getenv(Var) of
        false -> ok;
        "" -> ok;
        Raw -> application:set_env(App, Key, cast(Type, Var, Raw), [{persistent, true}])
    end.

cast(binary, _Var, Raw) ->
    list_to_binary(Raw);
cast(port, Var, Raw) ->
    case string:to_integer(Raw) of
        {Port, ""} when Port > 0, Port =< 65535 -> Port;
        _ -> erlang:error({bad_env_var, Var, Raw})
    end;
cast(chat_id, _Var, Raw) ->
    case string:to_integer(Raw) of
        {Int, ""} -> Int;
        _ -> list_to_binary(Raw)
    end.
