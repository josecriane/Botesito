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

-export([
  handle_update/1
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
%%% Internal states
%%%===================================================================
chat_active(_EventType, {new_message, Update = #teleg_update{}}, State = #chat_statem_state{}) ->
  handle_update(Update),
  {next_state, chat_active, State};
chat_active(_EventType, _EventContent, _State) ->
  {repeat_state_and_data, []}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
handle_update(Update) ->
  Message = Update#teleg_update.message,
  handle_message(Message).

handle_message(Message = #teleg_message{text = <<"/start">>}) ->
  {ok, response_start(Message)};
handle_message(Message = #teleg_message{text = <<"/help">>}) ->
  {ok, response_help(Message)};
handle_message(Message = #teleg_message{}) ->
  case string:slice(Message#teleg_message.text, 0, 1) of
    <<"/">> -> {ok, response_help(Message)};
    _ -> {no_handle, <<"">>}
  end.


%%%===================================================================
%%% Response functions
%%%===================================================================
response_start(Message = #teleg_message{}) ->
  User = Message#teleg_message.from,
  localized_utils:str(start, User#teleg_user.language_code).

response_help(Message = #teleg_message{}) ->
  User = Message#teleg_message.from,
  localized_utils:str(help, User#teleg_user.language_code).

