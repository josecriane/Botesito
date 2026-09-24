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
    ChildSpecs =
        [pool_child_spec(Name, Host) || {Name, Host} <- ?POOLS] ++ chatops_child_specs(),
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, ChildSpecs}}.

pool_child_spec(Name, Host) ->
    nhttpc:child_spec(Name, #{
        host => Host,
        port => 443,
        tls => #{wildcard_hostname => true},
        size => 4
    }).

chatops_child_specs() ->
    case application:get_env(botesito, chatops, false) of
        false ->
            [];
        true ->
            [
                k8s_pool_child_spec(),
                plain_pool_child_spec(prometheus_pool, botesito_monitoring:prometheus_host()),
                plain_pool_child_spec(alertmanager_pool, botesito_monitoring:alertmanager_host())
            ]
    end.

k8s_pool_child_spec() ->
    CaCertFile = filename:join(botesito_cluster:service_account_dir(), "ca.crt"),
    nhttpc:child_spec(k8s_pool, #{
        host => list_to_binary(botesito_cluster:api_host()),
        port => 443,
        tls => #{cacertfile => CaCertFile, verify => verify_peer},
        size => 2
    }).

plain_pool_child_spec(Name, HostPort) ->
    {Host, Port} = split_host_port(HostPort),
    nhttpc:child_spec(Name, #{
        host => Host,
        port => Port,
        size => 2
    }).

split_host_port(HostPort) ->
    case string:split(HostPort, ":", trailing) of
        [Host, Port] -> {list_to_binary(Host), list_to_integer(Port)};
        [Host] -> {list_to_binary(Host), 80}
    end.
