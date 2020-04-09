%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 09. Apr 2020 2:31 AM
%%%-------------------------------------------------------------------
-module(botesito_chat_statem).
-author("sito").

-behaviour(gen_statem).

-include("telegram_model.hrl").

%% API
-export([
  start_link/1,
  new_message/2
]).

%% gen_statem callbacks
-export([init/1,
  terminate/3,
  code_change/4,
  callback_mode/0]).

%% custom states
-export([
  chat_active/3
]).

-define(SERVER, ?MODULE).

-record(chat_statem_state, {chatId}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(ChatId) ->
  gen_statem:start_link(?MODULE, [ChatId], []).

new_message(Pid, Update) ->
  gen_statem:cast(Pid, {new_message, Update}).

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

init([ChatId]) ->
  {ok, chat_active, #chat_statem_state{chatId = ChatId}}.

callback_mode() ->
  state_functions.

terminate(_Reason, _StateName, _State = #chat_statem_state{}) ->
  ok.

code_change(_OldVsn, StateName, State = #chat_statem_state{}, _Extra) ->
  {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
chat_active(_EventType, {new_message, _Update = #teleg_update{}}, State = #chat_statem_state{}) ->
  {next_state, chat_active, State};
chat_active(_EventType, _EventContent, _State) ->
  {repeat_state_and_data, []}.
%%  NextStateName = next_state,
%%  {next_state, NextStateName, State}.