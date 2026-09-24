-module(botesito_commands).

-export([
    handle/1,
    parse/1,
    parse_duration/1
]).

-define(LOG_LINES, 15).
-define(MAX_REPLY, 3500).

-type command() ::
    help
    | status
    | alerts
    | {logs, binary()}
    | {restart, binary()}
    | {silence, binary(), pos_integer()}
    | {usage, binary()}
    | {unknown, binary()}
    | ignore.

-export_type([command/0]).

-spec parse(binary()) -> command().
parse(Text) when is_binary(Text) ->
    case string:lexemes(string:trim(Text), " \t\n") of
        [] -> ignore;
        [Command | Args] -> parse(strip_mention(Command), Args)
    end;
parse(_) ->
    ignore.

-spec handle(binary()) -> binary() | ignore.
handle(Text) ->
    case parse(Text) of
        ignore -> ignore;
        Command -> run(Command)
    end.

-spec parse_duration(binary()) -> {ok, pos_integer()} | error.
parse_duration(Duration) ->
    case string:to_integer(Duration) of
        {Value, Unit} when is_integer(Value), Value > 0 -> duration(Value, Unit);
        _ -> error
    end.

parse(<<"/help">>, _) -> help;
parse(<<"/start">>, _) -> help;
parse(<<"/status">>, _) -> status;
parse(<<"/alerts">>, _) -> alerts;
parse(<<"/logs">>, [App]) -> {logs, App};
parse(<<"/logs">>, _) -> {usage, <<"/logs <app>">>};
parse(<<"/restart">>, [App]) -> {restart, App};
parse(<<"/restart">>, _) -> {usage, <<"/restart <app>">>};
parse(<<"/silence">>, [Alert, Duration]) -> silence_command(Alert, Duration);
parse(<<"/silence">>, _) -> {usage, <<"/silence <alert> <duration, e.g. 2h>">>};
parse(<<"/", _/binary>> = Command, _) -> {unknown, Command};
parse(_, _) -> ignore.

silence_command(Alert, Duration) ->
    case parse_duration(Duration) of
        {ok, Seconds} -> {silence, Alert, Seconds};
        error -> {usage, <<"/silence <alert> <duration, e.g. 30m, 2h, 1d>">>}
    end.

duration(Value, <<"s">>) -> {ok, Value};
duration(Value, <<"m">>) -> {ok, Value * 60};
duration(Value, <<"h">>) -> {ok, Value * 3600};
duration(Value, <<"d">>) -> {ok, Value * 86400};
duration(_, _) -> error.

strip_mention(Command) ->
    case binary:split(Command, <<"@">>) of
        [Command] -> Command;
        [Bare, _Bot] -> Bare
    end.

run(help) ->
    <<
        "/status - nodes, pods that are not Running, firing alerts\n"
        "/alerts - firing alerts\n"
        "/logs <app> - last ",
        (integer_to_binary(?LOG_LINES))/binary,
        " log lines of an app\n"
        "/restart <app> - roll the app's deployment\n"
        "/silence <alert> <30m|2h|1d> - silence an alert in Alertmanager"
    >>;
run(status) ->
    Nodes = render_nodes(botesito_cluster:nodes()),
    Pods = render_pods(botesito_cluster:pods()),
    Alerts = render_alerts(botesito_monitoring:firing_alerts()),
    <<Nodes/binary, "\n", Pods/binary, "\n", Alerts/binary>>;
run(alerts) ->
    render_alerts(botesito_monitoring:firing_alerts());
run({logs, App}) ->
    case botesito_cluster:pod_logs(App, ?LOG_LINES) of
        {ok, <<>>} -> <<"no output from ", App/binary>>;
        {ok, Logs} -> truncate(Logs);
        {error, {not_found, _}} -> <<"no pod found for ", App/binary>>;
        {error, Reason} -> error_text(<<"logs">>, Reason)
    end;
run({restart, App}) ->
    case botesito_cluster:pods() of
        {error, Reason} ->
            error_text(<<"restart">>, Reason);
        {ok, Pods} ->
            case
                [Namespace || #{namespace := Namespace, name := Name} <- Pods, matches(Name, App)]
            of
                [] ->
                    <<"no pod found for ", App/binary>>;
                [Namespace | _] ->
                    case botesito_cluster:restart_deployment(Namespace, App) of
                        ok ->
                            ok = botesito_followup:after_restart(Namespace, App),
                            <<"rolled ", Namespace/binary, "/", App/binary, ", will report back">>;
                        {error, Reason} ->
                            error_text(<<"restart">>, Reason)
                    end
            end
    end;
run({silence, Alert, Seconds}) ->
    case botesito_monitoring:silence(Alert, Seconds, <<"botesito">>) of
        {ok, Id} ->
            ok = botesito_followup:after_silence(Alert, Seconds),
            <<"silenced ", Alert/binary, " for ", (human_duration(Seconds))/binary, ", id ",
                Id/binary>>;
        {error, Reason} ->
            error_text(<<"silence">>, Reason)
    end;
run({usage, Usage}) ->
    <<"usage: ", Usage/binary>>;
run({unknown, Command}) ->
    <<Command/binary, " is not a command, try /help">>.

matches(PodName, App) ->
    Size = byte_size(App),
    case PodName of
        <<App:Size/binary, "-", _/binary>> -> true;
        App -> true;
        _ -> false
    end.

render_nodes({error, Reason}) ->
    error_text(<<"nodes">>, Reason);
render_nodes({ok, Nodes}) ->
    Rendered = [<<Name/binary, " ", Ready/binary>> || #{name := Name, ready := Ready} <- Nodes],
    <<"nodes: ", (join(Rendered, <<", ">>))/binary>>.

render_pods({error, Reason}) ->
    error_text(<<"pods">>, Reason);
render_pods({ok, Pods}) ->
    Running = [P || #{phase := <<"Running">>} = P <- Pods],
    Broken = [
        P
     || #{phase := Phase} = P <- Pods, Phase =/= <<"Running">>, Phase =/= <<"Succeeded">>
    ],
    Header = <<
        "pods: ",
        (integer_to_binary(length(Running)))/binary,
        " running, ",
        (integer_to_binary(length(Broken)))/binary,
        " not"
    >>,
    case Broken of
        [] ->
            Header;
        _ ->
            Details = [
                <<Namespace/binary, "/", Name/binary, " ", Phase/binary>>
             || #{namespace := Namespace, name := Name, phase := Phase} <- Broken
            ],
            <<Header/binary, "\n  ", (join(Details, <<"\n  ">>))/binary>>
    end.

render_alerts({error, Reason}) ->
    error_text(<<"alerts">>, Reason);
render_alerts({ok, []}) ->
    <<"alerts: none">>;
render_alerts({ok, Alerts}) ->
    Details = [
        <<Name/binary, " (", Severity/binary, ") ", Summary/binary>>
     || #{name := Name, severity := Severity, summary := Summary} <- Alerts
    ],
    <<"alerts: ", (integer_to_binary(length(Alerts)))/binary, "\n  ",
        (join(Details, <<"\n  ">>))/binary>>.

human_duration(Seconds) when Seconds rem 86400 =:= 0 ->
    <<(integer_to_binary(Seconds div 86400))/binary, "d">>;
human_duration(Seconds) when Seconds rem 3600 =:= 0 ->
    <<(integer_to_binary(Seconds div 3600))/binary, "h">>;
human_duration(Seconds) when Seconds rem 60 =:= 0 ->
    <<(integer_to_binary(Seconds div 60))/binary, "m">>;
human_duration(Seconds) ->
    <<(integer_to_binary(Seconds))/binary, "s">>.

error_text(What, Reason) ->
    Rendered = iolist_to_binary(io_lib:format("~p", [Reason])),
    <<What/binary, " failed: ", (truncate(Rendered, 200))/binary>>.

truncate(Text) ->
    truncate(Text, ?MAX_REPLY).

truncate(Text, Max) when byte_size(Text) =< Max ->
    Text;
truncate(Text, Max) ->
    <<(binary:part(Text, 0, Max))/binary, "\n[truncated]">>.

join([], _Separator) ->
    <<>>;
join([Element], _Separator) ->
    Element;
join([Element | Rest], Separator) ->
    <<Element/binary, Separator/binary, (join(Rest, Separator))/binary>>.
