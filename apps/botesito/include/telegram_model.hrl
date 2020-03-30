-record(teleg_user, {
  id :: integer(),
  is_bot :: boolean(),
  first_name :: string(),
  username :: undefined | string()
}).

-record(teleg_chat, {
  id :: integer()
}).

-record(teleg_message, {
  id :: integer(),
  from :: #teleg_user{},
  chat :: #teleg_chat{},
  text :: undefined | string()
}).

-record(teleg_update, {
  id :: integer(),
  message :: #teleg_message{}
  }).