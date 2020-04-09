-module(botesito_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
  SupFlags = #{strategy => one_for_one,
    intensity => 0,
    period => 1},
  ChildSpecs = [
    {botesito_gen_srv,
    {botesito_gen_srv, start_link, []},
    permanent,
    5000,
    worker,
    [botesito_gen_srv]}
  ],
  {ok, {SupFlags, ChildSpecs}}.
