-module(botesito_utils_SUITE).
-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").

%%--------------------------------------------------------------------
%% CT callbacks
%%--------------------------------------------------------------------
suite() ->
  [{timetrap, {seconds, 10}}].

all() ->
  [token_with_file,
    token_without_file].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
%% Test read token file
token_with_file(_Config) ->
  create_file(),
  Token = botesito_utils:get_callback_path(),
  remove_file(),
  Token == <<"/TokenFile">>.

%% Token without file
token_without_file(_Config) ->
  Token = botesito_utils:get_callback_path(),
  remove_file(),
  Token == <<"/Token">>.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
create_file() ->
  {ok, Directory} = file:get_cwd(),
  file:write_file(Directory ++ "/.token", <<"123456:TokenFile">>).

remove_file() ->
  {ok, Directory} = file:get_cwd(),
  file:delete(Directory ++ "/.token").