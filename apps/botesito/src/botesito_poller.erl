-module(botesito_poller).

-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2
]).

-define(POLL_TIMEOUT, 25).
-define(BACKOFF, 5000).

-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{offset => drain()}, 0}.

handle_call(_Request, _From, State) ->
    {reply, {error, not_implemented}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(timeout, #{offset := Offset} = State) ->
    case telegram:get_updates(Offset, ?POLL_TIMEOUT) of
        {ok, Updates} ->
            {noreply, State#{offset := lists:foldl(fun handle_update/2, Offset, Updates)}, 0};
        {error, Reason} ->
            ?LOG_WARNING("getUpdates failed: ~p", [Reason]),
            {noreply, State, ?BACKOFF}
    end;
handle_info(_Info, State) ->
    {noreply, State, 0}.

drain() ->
    case telegram:get_updates(-1, 0) of
        {ok, []} ->
            0;
        {ok, Updates} ->
            Offset = lists:max([maps:get(<<"update_id">>, U, 0) || U <- Updates]) + 1,
            ?LOG_INFO("chatops skipping updates older than offset ~p", [Offset]),
            Offset;
        {error, Reason} ->
            ?LOG_WARNING("could not drain pending updates: ~p", [Reason]),
            0
    end.

handle_update(Update, Offset) ->
    NextOffset = max(Offset, maps:get(<<"update_id">>, Update, 0) + 1),
    case command_of(Update) of
        ignore ->
            NextOffset;
        {ok, Text} ->
            reply(Text),
            NextOffset
    end.

command_of(#{<<"message">> := #{<<"text">> := Text} = Message}) ->
    case from_configured_chat(Message) of
        true ->
            {ok, Text};
        false ->
            ?LOG_WARNING("ignoring a message from an unexpected chat"),
            ignore
    end;
command_of(_Update) ->
    ignore.

from_configured_chat(#{<<"chat">> := #{<<"id">> := Id}}) ->
    normalize(Id) =:= normalize(telegram:chat_id());
from_configured_chat(_Message) ->
    false.

normalize(undefined) -> undefined;
normalize(Id) when is_integer(Id) -> integer_to_binary(Id);
normalize(Id) when is_binary(Id) -> Id;
normalize(Id) when is_list(Id) -> list_to_binary(Id).

reply(Text) ->
    case botesito_commands:handle(Text) of
        ignore ->
            ok;
        Reply ->
            case botesito_app:send_message(Reply, #{}) of
                {ok, _} -> ok;
                {error, Reason} -> ?LOG_WARNING("could not answer ~s: ~p", [Text, Reason])
            end
    end.
