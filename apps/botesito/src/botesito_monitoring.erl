-module(botesito_monitoring).

-export([
    alertmanager_host/0,
    firing_alerts/0,
    prometheus_host/0,
    silence/3
]).

-define(DEFAULT_PROMETHEUS, "kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090").
-define(DEFAULT_ALERTMANAGER,
    "kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093"
).

-type alert() :: #{name := binary(), severity := binary(), summary := binary()}.

-export_type([alert/0]).

-spec prometheus_host() -> string().
prometheus_host() ->
    application:get_env(botesito, prometheus_host, ?DEFAULT_PROMETHEUS).

-spec alertmanager_host() -> string().
alertmanager_host() ->
    application:get_env(botesito, alertmanager_host, ?DEFAULT_ALERTMANAGER).

-spec firing_alerts() -> {ok, [alert()]} | {error, term()}.
firing_alerts() ->
    Url = url(prometheus_host(), <<"/api/v1/alerts">>),
    Opts = #{timeouts => #{request => 15000}},
    case handle_response(nhttpc:get(Url, Opts)) of
        {ok, Body} ->
            case decode(Body) of
                {ok, #{<<"data">> := #{<<"alerts">> := Alerts}}} ->
                    {ok, [alert(A) || A <- Alerts, is_firing(A), not is_watchdog(A)]};
                {ok, Other} ->
                    {error, {unexpected_body, Other}};
                {error, _} = Err ->
                    Err
            end;
        {error, _} = Err ->
            Err
    end.

-spec silence(binary(), pos_integer(), binary()) -> {ok, binary()} | {error, term()}.
silence(AlertName, Seconds, CreatedBy) ->
    Now = erlang:system_time(second),
    Payload = #{
        <<"matchers">> => [
            #{
                <<"name">> => <<"alertname">>,
                <<"value">> => AlertName,
                <<"isRegex">> => false,
                <<"isEqual">> => true
            }
        ],
        <<"startsAt">> => rfc3339(Now),
        <<"endsAt">> => rfc3339(Now + Seconds),
        <<"createdBy">> => CreatedBy,
        <<"comment">> => <<"Silenced from Telegram">>
    },
    Url = url(alertmanager_host(), <<"/api/v2/silences">>),
    Body = iolist_to_binary(json:encode(Payload)),
    Opts = #{
        headers => [{<<"content-type">>, <<"application/json">>}],
        timeouts => #{request => 15000}
    },
    case handle_response(nhttpc:post(Url, Body, Opts)) of
        {ok, Response} ->
            case decode(Response) of
                {ok, #{<<"silenceID">> := Id}} -> {ok, Id};
                {ok, Other} -> {error, {unexpected_body, Other}};
                {error, _} = Err -> Err
            end;
        {error, _} = Err ->
            Err
    end.

is_firing(#{<<"state">> := <<"firing">>}) -> true;
is_firing(_) -> false.

is_watchdog(#{<<"labels">> := #{<<"alertname">> := <<"Watchdog">>}}) -> true;
is_watchdog(_) -> false.

alert(#{<<"labels">> := Labels} = Alert) ->
    Annotations = maps:get(<<"annotations">>, Alert, #{}),
    #{
        name => maps:get(<<"alertname">>, Labels, <<"unknown">>),
        severity => maps:get(<<"severity">>, Labels, <<"none">>),
        summary => maps:get(<<"summary">>, Annotations, <<>>)
    }.

url(Host, Path) ->
    HostBin = list_to_binary(Host),
    <<"http://", HostBin/binary, Path/binary>>.

rfc3339(Seconds) ->
    list_to_binary(calendar:system_time_to_rfc3339(Seconds, [{offset, "Z"}])).

handle_response({ok, #{status := Status, body := Body}}) when Status >= 200, Status < 300 ->
    {ok, iolist_to_binary(Body)};
handle_response({ok, #{status := Status, body := Body}}) ->
    {error, {http_error, Status, iolist_to_binary(Body)}};
handle_response({error, _} = Err) ->
    Err.

decode(Body) ->
    try json:decode(Body) of
        Json -> {ok, Json}
    catch
        error:Reason -> {error, {decode_error, Reason}}
    end.
