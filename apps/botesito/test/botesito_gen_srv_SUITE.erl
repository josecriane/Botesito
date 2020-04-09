-module(botesito_gen_srv_SUITE).
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

  ct:log(sys_state, "white_box_tests: starting gen_server~n"),
  {ok, _Pid} = botesito_gen_srv:start_link(),

  ct:log(sys_state, "white_box_tests: init gen_server~n"),
  {ok, State} = botesito_gen_srv:init([]),

  ct:log(sys_state, "white_box_tests: test unknown call~n"),
  {reply, ok, State} = botesito_gen_srv:handle_call(unknown, dummy_from, State),

  ct:log(sys_state, "white_box_tests: test a cast~n"),
  {noreply, State} = botesito_gen_srv:handle_cast(dummy_msg, State),

  ct:log(sys_state, "white_box_tests: test an info call~n"),
  {noreply, State} = botesito_gen_srv:handle_info(dummy_info, State),

  ct:log(sys_state, "white_box_tests: test termination~n"),
  botesito_gen_srv:terminate(dummy_reason, State), % no check on return

  ct:log(sys_state, "white_box_tests: test code change call~n"),
  {ok, State} = botesito_gen_srv:code_change(dummy_old_vsn, State, dummy_extra).