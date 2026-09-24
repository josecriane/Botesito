-module(botesito_followup).

-include_lib("kernel/include/logger.hrl").

-export([
    after_restart/2,
    after_silence/2,
    format_rollout/3,
    report_rollout/3,
    report_silence_expiry/1
]).

-define(ROLLOUT_DELAY_SECONDS, 30).
-define(ROLLOUT_ATTEMPTS, 6).

-spec after_restart(binary(), binary()) -> ok.
after_restart(Namespace, Name) ->
    schedule(
        ntask:task(?MODULE, report_rollout, [Namespace, Name, ?ROLLOUT_ATTEMPTS]),
        ?ROLLOUT_DELAY_SECONDS,
        <<"rollout report">>
    ).

-spec after_silence(binary(), pos_integer()) -> ok.
after_silence(AlertName, Seconds) ->
    schedule(
        ntask:task(?MODULE, report_silence_expiry, [AlertName]),
        Seconds,
        <<"silence expiry">>
    ).

-spec report_rollout(binary(), binary(), non_neg_integer()) -> ok.
report_rollout(Namespace, Name, AttemptsLeft) ->
    case botesito_cluster:deployment_status(Namespace, Name) of
        {error, Reason} ->
            ?LOG_WARNING("could not read the rollout of ~s/~s: ~p", [Namespace, Name, Reason]),
            tell(<<"could not check ", Name/binary, " after the roll">>);
        {ok, Rollout} ->
            case {settled(Rollout), AttemptsLeft} of
                {false, Left} when Left > 1 ->
                    schedule(
                        ntask:task(?MODULE, report_rollout, [Namespace, Name, Left - 1]),
                        ?ROLLOUT_DELAY_SECONDS,
                        <<"rollout report">>
                    );
                {Settled, _} ->
                    tell(format_rollout(Name, Rollout, Settled))
            end
    end.

-spec report_silence_expiry(binary()) -> ok.
report_silence_expiry(AlertName) ->
    tell(<<"the silence for ", AlertName/binary, " has expired">>).

-spec format_rollout(binary(), botesito_cluster:rollout(), boolean()) -> binary().
format_rollout(Name, #{desired := Desired, ready := Ready}, true) ->
    <<Name/binary, " rolled, ", (counts(Ready, Desired))/binary, " ready">>;
format_rollout(Name, #{desired := Desired, ready := Ready}, false) ->
    <<Name/binary, " is still rolling, ", (counts(Ready, Desired))/binary, " ready">>.

settled(#{desired := Desired, updated := Updated, ready := Ready}) ->
    Updated >= Desired andalso Ready >= Desired.

counts(Ready, Desired) ->
    <<(integer_to_binary(Ready))/binary, "/", (integer_to_binary(Desired))/binary>>.

schedule(Task, Seconds, What) ->
    case ntask:add_task(Task, due_at(Seconds)) of
        {ok, _Ref} ->
            ok;
        {error, Reason} ->
            ?LOG_WARNING("could not schedule the ~s: ~p", [What, Reason]),
            ok
    end.

due_at(Seconds) ->
    calendar:gregorian_seconds_to_datetime(
        calendar:datetime_to_gregorian_seconds(calendar:universal_time()) + Seconds
    ).

tell(Text) ->
    case botesito_app:send_message(Text, #{}) of
        {ok, _} ->
            ok;
        {error, Reason} ->
            ?LOG_WARNING("could not send a follow-up: ~p", [Reason]),
            ok
    end.
