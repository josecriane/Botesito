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
  [white_box_tests,
    response_start_message,
    response_help_message,
    response_no_response_message,
    response_unknown_command].

init_per_suite(Config) ->
  {ok, Pid} = botesito_chat_statem:start_link(0),
  InitialChat = botesito_chat_statem:init([0]),
  [{chat_pid, Pid}|[{initial_chat_statem, InitialChat}|Config]].

end_per_suite(Config) ->
  Config.

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
response_start_message(_Config) ->
  [Update1|[Update2|_]] = botesito_parser:parse_data(ct:get_config(json_two_start_message)),
  {ok, EsResponse} = botesito_chat_statem:handle_update(Update1),
  {ok, EnResponse} = botesito_chat_statem:handle_update(Update2),

  {EsResponse, EnResponse} == {localized_utils:str(start, "es"), localized_utils:str(start, "en")}.

response_help_message(_Config) ->
  [Update1|[Update2|_]] = botesito_parser:parse_data(ct:get_config(json_two_help_message)),
  {ok, EsResponse} = botesito_chat_statem:handle_update(Update1),
  {ok, EnResponse} = botesito_chat_statem:handle_update(Update2),

  {EsResponse, EnResponse} == {localized_utils:str(help, "es"), localized_utils:str(help, "en")}.

response_no_response_message(_Config) ->
  [Update|_] = botesito_parser:parse_data(ct:get_config(json_no_response_message)),
  {no_handle, _} = botesito_chat_statem:handle_update(Update).

response_unknown_command(_Config) ->
  [Update1|_] = botesito_parser:parse_data(ct:get_config(json_unknown_command)),
  {ok, EsResponse} = botesito_chat_statem:handle_update(Update1),

  EsResponse == localized_utils:str(help, "es").

white_box_tests(Config) ->
  ct:log(sys_state, "white_box_tests: start~n"),

  {ok, chat_active, Status} = ?config(initial_chat_statem, Config),

  [Update|_] = botesito_parser:parse_data(ct:get_config(json_start_message)),

  {ok, chat_active, Status} = botesito_chat_statem:code_change({0,0,1}, chat_active, Status, []),

  {next_state, chat_active, Status} = botesito_chat_statem:chat_active(cast, {new_message, Update}, Status),
  {repeat_state_and_data, []} = botesito_chat_statem:chat_active(cast, {new_message, #{}}, Status),
  {repeat_state_and_data, []} = botesito_chat_statem:chat_active(cast, {unknown}, Status),

  ok = botesito_chat_statem:terminate(normal, chat_active, Status).

