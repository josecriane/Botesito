%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Apr 2020 3:29 PM
%%%-------------------------------------------------------------------
-module(botesito_gen_srv).
-author("sito").

-behaviour(gen_server).

-include("telegram_model.hrl").

%% API
-export([
  start_link/0,
  new_message/1
  ]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(srv_state, {
  chat_pids
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

new_message(Update) ->
  gen_server:cast(?MODULE, {new_message, Update}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
init([]) ->
  State = #srv_state{chat_pids = #{}},
  {ok, State}.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast({new_message, Update = #teleg_update{}}, State = #srv_state{}) ->
  ChatId = telegram_model_utils:chat_id_from_update(Update),
  NewState = case maps:find(ChatId, State#srv_state.chat_pids) of
    {ok, Pid} ->
      botesito_chat_statem:new_message(Pid, Update),
      State;
    error ->
      Pid = create_chat_monitor(ChatId),
      NewMap = maps:put(ChatId, Pid, State#srv_state.chat_pids),
      botesito_chat_statem:new_message(Pid, Update),
      State#srv_state{chat_pids =  NewMap}
  end,
  {noreply, NewState};
handle_cast(_Data, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
create_chat_monitor(ChatId) ->
  {ok, Pid} = botesito_chat_statem:start_link(ChatId),
  Pid.