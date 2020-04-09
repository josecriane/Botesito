-module(botesito_chat_statem_SUITE).
-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% CT callbacks
%%--------------------------------------------------------------------
suite() ->
  [{timetrap, {seconds, 10}}].

all() ->
  [white_box_tests].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
white_box_tests(_Config) ->
  ct:log(sys_state, "white_box_tests: start~n"),

  [Update|_] = botesito_parser:parse_data(ct:get_config(json_start_message)),

  ct:log(sys_state, "white_box_tests: starting gen_server~n"),
  {ok, _Pid} = botesito_chat_statem:start_link(0),

  ct:log(sys_state, "white_box_tests: init gen_server~n"),
  {ok, chat_active, Status} = botesito_chat_statem:init([0]),

  {ok, chat_active, Status} = botesito_chat_statem:code_change({0,0,1}, chat_active, Status, []),

  {next_state, chat_active, Status} = botesito_chat_statem:chat_active(cast, {new_message, Update}, Status),
  {repeat_state_and_data, []} = botesito_chat_statem:chat_active(cast, {new_message, #{}}, Status),
  {repeat_state_and_data, []} = botesito_chat_statem:chat_active(cast, {unknown}, Status),

  ok = botesito_chat_statem:terminate(normal, chat_active, Status).

