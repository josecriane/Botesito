%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 06. Apr 2020 7:56 PM
%%%-------------------------------------------------------------------
-module(botesito_utils).
-author("sito").

%% API
-export([
  get_callback_path/0
]).

get_callback_path() ->
  Token = lists:last(string:tokens(get_token(), ":")),
  "/" ++ Token.

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_token() ->
  {ok, Directory} = file:get_cwd(),
  Token = case file:read_file(token_file(Directory)) of
            {ok, DataToken} -> DataToken;
            {error, _} -> <<"No:Token">>
          end,
  binary_to_list(Token).

token_file(Directory) ->
  Directory ++ "/.token".
