% https://core.telegram.org/bots/api#user
-record(teleg_user, {
  id = 0 :: integer(),
  is_bot = false :: boolean(),
  first_name = "" :: string(),
  last_name :: undefined | string(),
  username :: undefined | string(),
  language_code :: undefined | string()
}).

-record(teleg_chat, {
  id = 0 :: integer()
}).

-record(teleg_message, {
  id = 0 :: integer(),
  from :: undefined | #teleg_user{},
  chat = #teleg_chat{id = 0} :: #teleg_chat{},
  text :: undefined | string()
}).

-record(teleg_update, {
  id = 0 :: integer(),
  message :: undefined | #teleg_message{}
  }).