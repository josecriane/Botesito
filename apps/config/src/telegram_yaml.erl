-module(telegram_yaml).

-behaviour(conf).

-export([validator/0]).

-spec validator() -> yval:validator().
validator() ->
    yval:options(
        #{
            bot_token => yval:binary(),
            chat_id => yval:either(yval:int(), yval:binary())
        },
        [
            unique,
            {defaults, #{
                bot_token => undefined,
                chat_id => undefined
            }}
        ]
    ).
