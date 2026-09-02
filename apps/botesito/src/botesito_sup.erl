-module(botesito_sup).

-behaviour(supervisor).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, Port} = application:get_env(botesito, port),
    {ok, SpecPath} = application:get_env(botesito, spec_path),
    ok = assert_api_token(),

    ApiConf = #{
        name => botesito_api,
        port => Port,
        spec_path => SpecPath,
        callback => botesito_callback,
        http_server => {nhttp_erf_server, #{}},
        preprocess_middlewares => [nhttp_erf_request_id],
        postprocess_middlewares => [nhttp_erf_timing, nhttp_erf_logging]
    },

    ApiSpec = #{
        id => botesito_api,
        start => {erf, start_link, [ApiConf]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [erf]
    },

    PoolsSpec = #{
        id => botesito_pools_sup,
        start => {botesito_pools_sup, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => supervisor,
        modules => [botesito_pools_sup]
    },

    {ok, {{one_for_one, 5, 10}, [PoolsSpec, ApiSpec]}}.

assert_api_token() ->
    case application:get_env(botesito, api_token, undefined) of
        undefined ->
            ?LOG_CRITICAL(
                "botesito: api_token is not configured; every request would be "
                "rejected. Set BOTESITO_API_TOKEN, or botesito.api_token in "
                "the YAML config."
            ),
            erlang:error(missing_api_token);
        <<>> ->
            erlang:error(missing_api_token);
        _ ->
            ok
    end.
