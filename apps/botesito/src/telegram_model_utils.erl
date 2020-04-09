
-module(telegram_model_utils).
-include("telegram_model.hrl").

%% API
-export([
  chat_id_from_update/1
]).

chat_id_from_update(Update = #teleg_update{}) ->
  Message = Update#teleg_update.message,
  Chat = Message#teleg_message.chat,
  Chat#teleg_chat.id.
