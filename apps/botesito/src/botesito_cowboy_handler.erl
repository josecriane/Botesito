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
  {ok, Data, Req} = cowboy_req:read_body(Req0),
  JsonUpdates = botesito_parser:parse_data(Data),
  % handle_updates(JsonUpdates) // Exec on other thread
  Req2 = case JsonUpdates of
    [_] ->
      cowboy_req:reply(200, Req);
    _ ->
      cowboy_req:reply(422, Req)
  end,

  {ok, Req2, State}.
