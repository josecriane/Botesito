-module(botesito_pools_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(POOLS, [
    {telegram_pool, <<"api.telegram.org">>}
]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ChildSpecs = [pool_child_spec(Name, Host) || {Name, Host} <- ?POOLS],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, ChildSpecs}}.

pool_child_spec(Name, Host) ->
    nhttpc:child_spec(Name, #{
        host => Host,
        port => 443,
        tls => #{wildcard_hostname => true},
        size => 4
    }).
