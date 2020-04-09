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
  Updates = botesito_parser:parse_data(Data),
  handle_updates(Updates),
  Req2 = case length(Updates) of
           0 -> cowboy_req:reply(422, Req);
           _ -> cowboy_req:reply(200, Req)
         end,

  {ok, Req2, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
handle_updates([]) ->
  ok;
handle_updates([Update|Tail]) ->
  botesito_gen_srv:new_message(Update),
  handle_updates(Tail).

