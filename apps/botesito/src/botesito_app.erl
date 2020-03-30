-module(botesito_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    io:format("--- Start botesito ---\n"),
    Path = get_callback_path(),
    Dispatch = cowboy_router:compile(
        [{'_', [{Path, botesito_cowboy_handler, []}]}]),
    {ok, _} = cowboy:start_clear(my_http_listener,
        [
            {port, 8080},
            {ip, {127,0,0,1}}
        ],
        #{env => #{dispatch => Dispatch}}),
    botesito_sup:start_link().

stop(_State) ->
    io:format("--- Stop botesito ---"),
    ok.


%%%===================================================================
%%% Internal functions
%%%===================================================================
get_token() ->
    {ok, Directory} = file:get_cwd(),
    {ok, Data} = file:read_file(Directory ++ "/.token"),
    binary_to_list(Data).

get_callback_path() ->
    Token = lists:last(string:tokens(get_token(), ":")),
    "/" ++ Token.
