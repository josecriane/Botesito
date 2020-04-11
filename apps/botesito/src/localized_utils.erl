%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. Apr 2020 7:21 PM
%%%-------------------------------------------------------------------
-module(localized_utils).
-author("sito").

%% API
-export([str/2]).

%%%===================================================================
%%% API
%%%===================================================================
str(Atom, LangCountry) ->
  Lang = string:slice(LangCountry, 0, 2),
  case Atom of
    help -> localized_help(Lang);
    start -> localized_start(Lang)
  end.


%%%===================================================================
%%% Internal functions
%%%===================================================================
localized_help(Lang) ->
  case Lang of
    "es" -> <<"Mensaje de /help">>;
    "en" -> <<"/help message">>;
    _ -> localized_help("en")
  end.

localized_start(Lang) ->
  case Lang of
    "es" -> <<"Hola, gracias por usar el botesito, utiliza /help para ver los comandos disponibles.">>;
    "en" -> <<"Hi thanks to use botesito, use /help to see the commands.">>;
    _ -> localized_start("en")
  end.
