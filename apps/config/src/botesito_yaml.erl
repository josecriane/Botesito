-module(botesito_yaml).

-behaviour(conf).

-export([validator/0]).

-spec validator() -> yval:validator().
validator() ->
    yval:options(
        #{
            port => yval:port(),
            spec_path => yval:binary(),
            api_token => yval:binary()
        },
        [
            unique,
            {defaults, #{
                port => 8080,
                spec_path => <<"docs/openapi.json">>,
                api_token => undefined
            }}
        ]
    ).
