%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. Apr 2020 7:56 PM
%%%-------------------------------------------------------------------
-module(botesito_localized_utils_SUITE).
-compile(export_all).
-compile(nowarn_export_all).

-include_lib("common_test/include/ct.hrl").

suite() ->
  [{timetrap, {seconds, 10}}].

all() ->
  [start_en_test,
  start_es_test,
  start_unknown_test,
  help_en_test,
  help_es_test,
  help_unknown_test
].


%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
start_en_test(_Config) ->
  <<"Hi thanks to use botesito, use /help to see the commands.">> = localized_utils:str(start, "en").

start_es_test(_Config) ->
  <<"Hola, gracias por usar el botesito, utiliza /help para ver los comandos disponibles.">> = localized_utils:str(start, "es").

start_unknown_test(_Config) ->
  <<"Hi thanks to use botesito, use /help to see the commands.">> = localized_utils:str(start, "un").

help_en_test(_Config) ->
  <<"/help message">> = localized_utils:str(help, "en").

help_es_test(_Config) ->
  <<"Mensaje de /help">> = localized_utils:str(help, "es").

help_unknown_test(_Config) ->
  <<"/help message">> = localized_utils:str(help, "un").

no_text_test(_Config) ->
  string:is_empty(localized_utils:str(unknown, "es")).

