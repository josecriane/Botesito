% https://core.telegram.org/bots/api#user
-record(teleg_user, {
  id :: integer(),
  is_bot :: boolean(),
  first_name :: string(),
  last_name :: undefined | string(),
  username :: undefined | string(),
  language_code :: undefined | string()
}).

-record(teleg_chat, {
  id :: integer()
}).

-record(teleg_message, {
  id :: integer(),
  from :: undefined | #teleg_user{},
  chat :: #teleg_chat{},
  text :: undefined | string()
}).

-record(teleg_update, {
  id :: integer(),
  message :: undefined | #teleg_message{}
  }).