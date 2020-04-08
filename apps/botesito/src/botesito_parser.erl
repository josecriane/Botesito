%%%-------------------------------------------------------------------
%%% @author sito
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(botesito_parser).

-include("telegram_model.hrl").

-export([parse_data/1]).

parse_data(Data) ->
  JsonUpdate = jiffy:decode(Data),
  parse_json(JsonUpdate).

%%%===================================================================
%%% Internal functions
%%%===================================================================

parse_json(JsonUpdates) when is_list(JsonUpdates) ->
  Updates = [json_to_update(JsonUpdate, #teleg_update{}) || {JsonUpdate} <- JsonUpdates],
  lists:filter(fun(Update) -> Update#teleg_update.id /= 0 end, Updates);
parse_json(JsonUpdate) ->
  parse_json([JsonUpdate]).

json_to_update([], Update) ->
  Update;
json_to_update([{<<"update_id">>, V}|Json], Update) ->
  json_to_update(Json, Update#teleg_update{id = V});
json_to_update([{<<"message">>, {V}}|Json], Update) ->
  json_to_update(Json, Update#teleg_update{message = json_to_message(V, #teleg_message{})});
json_to_update([_|Json], Update) ->
  json_to_update(Json, Update).

json_to_message([], Message) ->
  Message;
json_to_message([{<<"message_id">>, V}|Json], Message) ->
  json_to_message(Json, Message#teleg_message{id = V});
json_to_message([{<<"from">>, {V}}|Json], Message) ->
  json_to_message(Json, Message#teleg_message{from = json_to_user(V, #teleg_user{})});
json_to_message([{<<"chat">>, {V}}|Json], Message) ->
  json_to_message(Json, Message#teleg_message{chat = json_to_chat(V, #teleg_chat{})});
json_to_message([{<<"text">>, V}|Json], Message) ->
  json_to_message(Json, Message#teleg_message{text = V});
json_to_message([_|Json], Message) ->
  json_to_message(Json, Message).

json_to_user([], User) when User#teleg_user.id /= 0 ->
  User;
json_to_user([{<<"id">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{id = V});
json_to_user([{<<"is_bot">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{is_bot = V});
json_to_user([{<<"first_name">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{first_name = V});
json_to_user([{<<"last_name">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{last_name = V});
json_to_user([{<<"username">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{username = V});
json_to_user([{<<"language_code">>, V}|Json], User) ->
  json_to_user(Json, User#teleg_user{language_code = V});
json_to_user([_|Json], User) ->
  json_to_user(Json, User).

json_to_chat([], Chat) ->
  Chat;
json_to_chat([{<<"id">>, V}|Json], Chat) ->
  json_to_chat(Json, Chat#teleg_chat{id = V});
json_to_chat([_|Json], Chat) ->
  json_to_chat(Json, Chat).
