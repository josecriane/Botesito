-module(botesito_cowboy_handler).

-author("sito").
-behaviour(cowboy_handler).

-include("telegram_model.hrl").

%% API
-export([init/2]).

%%--------------------------------------------------------------------
%% cowboy_handler functions
%%--------------------------------------------------------------------
init(Req0, State) ->
  <<"POST">> = cowboy_req:method(Req0),
  {ok, Data, _} = cowboy_req:read_body(Req0),
  Req = cowboy_req:reply(200, #{}, "", Req0),
  io:format(Data),
  botesito_parser:parse_updates(Data),

  {ok, Req, State}.


