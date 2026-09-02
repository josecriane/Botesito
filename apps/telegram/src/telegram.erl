-module(telegram).

-export([
    available/0,
    chat_id/0,
    get_me/0,
    send_message/2
]).

-define(BASE_URL, <<"https://api.telegram.org">>).
-define(POOL, telegram_pool).

-type send_opts() :: #{
    parse_mode => binary(),
    silent => boolean(),
    preview_links => boolean()
}.

-type message() :: #{binary() => term()}.

-export_type([message/0, send_opts/0]).

-spec available() -> boolean().
available() ->
    bot_token() =/= undefined andalso chat_id() =/= undefined.

-spec chat_id() -> integer() | binary() | undefined.
chat_id() ->
    case application:get_env(telegram, chat_id, undefined) of
        undefined -> undefined;
        <<>> -> undefined;
        Int when is_integer(Int) -> Int;
        Bin when is_binary(Bin) -> Bin;
        L when is_list(L) -> list_to_binary(L)
    end.

-spec get_me() -> {ok, message()} | {error, term()}.
get_me() ->
    call(<<"getMe">>, #{}).

-spec send_message(binary(), send_opts()) ->
    {ok, message()} | {error, term()}.
send_message(Text, Opts) when is_binary(Text), is_map(Opts) ->
    case chat_id() of
        undefined ->
            {error, no_chat_configured};
        ChatId ->
            Payload = build_payload(ChatId, Text, Opts),
            call(<<"sendMessage">>, Payload)
    end.

build_payload(ChatId, Text, Opts) ->
    Base = #{<<"chat_id">> => ChatId, <<"text">> => Text},
    Base1 = maybe_put(<<"parse_mode">>, telegram_parse_mode(Opts), Base),
    Base2 = maybe_put(
        <<"disable_notification">>, maps:get(silent, Opts, undefined), Base1
    ),
    maybe_put(
        <<"link_preview_options">>,
        link_preview_options(maps:get(preview_links, Opts, false)),
        Base2
    ).

telegram_parse_mode(Opts) ->
    case maps:get(parse_mode, Opts, undefined) of
        undefined -> undefined;
        <<"plain">> -> undefined;
        <<"markdown">> -> <<"MarkdownV2">>;
        <<"html">> -> <<"HTML">>
    end.

link_preview_options(true) -> undefined;
link_preview_options(_) -> #{<<"is_disabled">> => true}.

maybe_put(_Key, undefined, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.

call(Method, Payload) ->
    case bot_token() of
        undefined ->
            {error, missing_credentials};
        Token ->
            Url = <<?BASE_URL/binary, "/bot", Token/binary, "/", Method/binary>>,
            Body = iolist_to_binary(json:encode(Payload)),
            Headers = [
                {<<"content-type">>, <<"application/json">>},
                {<<"accept">>, <<"application/json">>}
            ],
            Opts = #{via => {pool, ?POOL}, headers => Headers},
            handle_response(nhttpc:post(Url, Body, Opts))
    end.

handle_response({ok, #{status := 200, body := Body}}) ->
    case decode(Body) of
        {ok, #{<<"ok">> := true, <<"result">> := Result}} ->
            {ok, Result};
        {ok, Json} ->
            {error, {telegram_error, api_error_reason(Json)}};
        {error, _} = Err ->
            Err
    end;
handle_response({ok, #{status := Status, body := Body}}) ->
    case decode(Body) of
        {ok, Json} -> {error, {telegram_error, Status, api_error_reason(Json)}};
        {error, _} -> {error, {http_error, Status, iolist_to_binary(Body)}}
    end;
handle_response({error, _} = Err) ->
    Err.

api_error_reason(#{<<"description">> := Desc}) -> Desc;
api_error_reason(Json) -> iolist_to_binary(io_lib:format("~p", [Json])).

decode(Body) ->
    try json:decode(iolist_to_binary(Body)) of
        Json -> {ok, Json}
    catch
        error:R -> {error, {decode_error, R}}
    end.

bot_token() ->
    case application:get_env(telegram, bot_token, undefined) of
        undefined -> undefined;
        <<>> -> undefined;
        Bin when is_binary(Bin) -> Bin;
        L when is_list(L) -> list_to_binary(L)
    end.
