-module(botesito_SUITE).
-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% CT callbacks
%%--------------------------------------------------------------------
suite() ->
  [{timetrap, {seconds, 10}}].

all() ->
  [parse_update,
  parse_update_err].

init_per_suite(Config) ->
  {ok, AppStartList} = application:ensure_all_started(botesito),
  [{app_start_list, AppStartList}|Config].

end_per_suite(Config) ->
  [application:stop(App) || App <- ?config(app_start_list, Config)],
  Config.

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
%% Test that can parse a update array.
parse_update(_Config) ->
Status = post_update(ct:get_config(json_start_message)),
  200 = Status.

parse_update_err(_Config) ->
  Status = post_update(ct:get_config(json_err_message)),
  422 = Status.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
post_update(Data) ->
  Callback = botesito_utils:get_callback_path(),
  {ok, {{_, Status, _}, _, _}} =
    httpc:request(post, {"http://localhost:8080" ++ Callback, [],
      "application/json", Data}, [], []),
  Status.
