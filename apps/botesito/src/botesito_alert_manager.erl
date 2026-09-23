-module(botesito_alert_manager).

-export([format/1]).

-define(MAX_LENGTH, 4096).
-define(SUFFIX_RESERVE, 64).
-define(LINE_LIMIT, 300).
-define(CONTEXT_LABELS, [
    <<"namespace">>,
    <<"pod">>,
    <<"instance">>,
    <<"node">>,
    <<"service">>,
    <<"job">>
]).

-spec format(map()) -> binary().
format(Body) ->
    Blocks = [block(Alert) || Alert <- alerts(Body)],
    Header = header(Body, length(Blocks)),
    Budget = ?MAX_LENGTH - byte_size(Header) - ?SUFFIX_RESERVE,
    Kept = keep(Blocks, Budget),
    Extra = length(Blocks) - length(Kept) + truncated(Body),
    join(<<"\n\n">>, [Header | Kept] ++ suffix(Extra)).

alerts(Body) ->
    case maps:get(<<"alerts">>, Body, []) of
        Alerts when is_list(Alerts) -> Alerts;
        _ -> []
    end.

header(Body, Count) ->
    iolist_to_binary([status(Body), " ", integer_to_binary(Count), " ", noun(Count)]).

status(Body) ->
    case maps:get(<<"status">>, Body, <<"firing">>) of
        Status when is_binary(Status), Status =/= <<>> -> string:uppercase(Status);
        _ -> <<"FIRING">>
    end.

noun(1) -> <<"alert">>;
noun(_) -> <<"alerts">>.

truncated(Body) ->
    case maps:get(<<"truncatedAlerts">>, Body, 0) of
        Count when is_integer(Count), Count > 0 -> Count;
        _ -> 0
    end.

block(Alert) ->
    Labels = submap(<<"labels">>, Alert),
    Annotations = submap(<<"annotations">>, Alert),
    join(<<"\n">>, [title(Labels)] ++ summary(Annotations) ++ context(Labels)).

submap(Key, Map) when is_map(Map) ->
    case maps:get(Key, Map, #{}) of
        Sub when is_map(Sub) -> Sub;
        _ -> #{}
    end;
submap(_Key, _Map) ->
    #{}.

title(Labels) ->
    Name = clip(text(maps:get(<<"alertname">>, Labels, <<"unknown">>)), ?LINE_LIMIT),
    case maps:find(<<"severity">>, Labels) of
        error -> Name;
        {ok, Severity} -> iolist_to_binary(["[", text(Severity), "] ", Name])
    end.

summary(Annotations) ->
    case first_present([<<"summary">>, <<"description">>], Annotations) of
        undefined -> [];
        Value -> [clip(text(Value), ?LINE_LIMIT)]
    end.

first_present([], _Map) ->
    undefined;
first_present([Key | Rest], Map) ->
    case maps:get(Key, Map, undefined) of
        undefined -> first_present(Rest, Map);
        <<>> -> first_present(Rest, Map);
        Value -> Value
    end.

context(Labels) ->
    Pairs = [
        [Key, "=", text(Value)]
     || Key <- ?CONTEXT_LABELS, {ok, Value} <- [maps:find(Key, Labels)]
    ],
    case Pairs of
        [] -> [];
        _ -> [clip(iolist_to_binary(lists:join(" ", Pairs)), ?LINE_LIMIT)]
    end.

keep([], _Budget) ->
    [];
keep([First | _] = Blocks, Budget) ->
    case take(Blocks, Budget, []) of
        [] -> [clip(First, Budget)];
        Kept -> Kept
    end.

take([], _Remaining, Kept) ->
    lists:reverse(Kept);
take([Block | Rest], Remaining, Kept) ->
    Cost = byte_size(Block) + 2,
    case Cost =< Remaining of
        true -> take(Rest, Remaining - Cost, [Block | Kept]);
        false -> lists:reverse(Kept)
    end.

suffix(Extra) when Extra > 0 ->
    [iolist_to_binary(["+", integer_to_binary(Extra), " more"])];
suffix(_Extra) ->
    [].

clip(Value, Limit) when byte_size(Value) =< Limit ->
    Value;
clip(Value, Limit) ->
    unicode:characters_to_binary([string:slice(Value, 0, max(Limit - 3, 0)), "..."]).

text(Value) when is_binary(Value) -> Value;
text(Value) when is_integer(Value) -> integer_to_binary(Value);
text(Value) when is_atom(Value) -> atom_to_binary(Value);
text(Value) -> iolist_to_binary(io_lib:format("~p", [Value])).

join(Separator, Parts) ->
    iolist_to_binary(lists:join(Separator, Parts)).
