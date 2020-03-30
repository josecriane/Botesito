%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(botesito_parser).

-behaviour(gen_server).

-include("telegram_model.hrl").

-export([start_link/0,
  parse_data/1]).

-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(botesito_parser_state, {}).

%%%===================================================================
%%% Spawning and gen_server implementation
%%%===================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec parse_data(Data :: binary()) -> ok.
parse_data(Data) ->
  JsonUpdates = jiffy:decode(Data),
  parse_json(JsonUpdates),
  ok.

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------
init([]) ->
  {ok, #botesito_parser_state{}}.

handle_call(_Request, _From, State = #botesito_parser_state{}) ->
  {reply, ok, State}.

handle_cast(_Request, State = #botesito_parser_state{}) ->
  {noreply, State}.

handle_info(_Info, State = #botesito_parser_state{}) ->
  {noreply, State}.

terminate(_Reason, _State = #botesito_parser_state{}) ->
  ok.

code_change(_OldVsn, State = #botesito_parser_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
parse_json(JsonUpdates) ->
  io:format(JsonUpdates).

%%  [json_to_update(JsonUpdate, #teleg_update{}) || {JsonUpdate} <- JsonUpdates].

%%json_to_update([], Update) ->
%%  Update;
%%json_to_update([_|Tail], Update) ->
%%  json_to_update(Tail, Update).