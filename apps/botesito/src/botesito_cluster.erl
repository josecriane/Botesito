-module(botesito_cluster).

-export([
    api_host/0,
    nodes/0,
    pod_count/0,
    pods_not_running/0,
    deployment_namespace/1,
    deployment_status/2,
    pod_logs/2,
    restart_deployment/2,
    service_account_dir/0
]).

-dialyzer({no_match, handle_response/1}).

-define(DEFAULT_HOST, "kubernetes.default.svc").
-define(DEFAULT_SA_DIR, "/var/run/secrets/kubernetes.io/serviceaccount").

-type node_info() :: #{name := binary(), ready := binary()}.
-type rollout() :: #{
    desired := non_neg_integer(), updated := non_neg_integer(), ready := non_neg_integer()
}.

-type pod_info() :: #{
    namespace := binary(), name := binary(), phase := binary(), ready := binary()
}.

-export_type([node_info/0, pod_info/0, rollout/0]).

-spec api_host() -> string().
api_host() ->
    application:get_env(botesito, k8s_host, ?DEFAULT_HOST).

-spec service_account_dir() -> string().
service_account_dir() ->
    application:get_env(botesito, k8s_service_account_dir, ?DEFAULT_SA_DIR).

-spec nodes() -> {ok, [node_info()]} | {error, term()}.
nodes() ->
    case get_json(<<"/api/v1/nodes">>) of
        {ok, #{<<"items">> := Items}} -> {ok, [node_info(Item) || Item <- Items]};
        {ok, Other} -> {error, {unexpected_body, Other}};
        {error, _} = Err -> Err
    end.

-spec pod_count() -> {ok, non_neg_integer()} | {error, term()}.
pod_count() ->
    case get_json(<<"/api/v1/pods?limit=1">>) of
        {ok, #{<<"items">> := Items, <<"metadata">> := Metadata}} ->
            {ok, length(Items) + maps:get(<<"remainingItemCount">>, Metadata, 0)};
        {ok, Other} ->
            {error, {unexpected_body, Other}};
        {error, _} = Err ->
            Err
    end.

-spec pods_not_running() -> {ok, [pod_info()]} | {error, term()}.
pods_not_running() ->
    case get_json(<<"/api/v1/pods?fieldSelector=status.phase%21%3DRunning">>) of
        {ok, #{<<"items">> := Items}} -> {ok, [pod_info(Item) || Item <- Items]};
        {ok, Other} -> {error, {unexpected_body, Other}};
        {error, _} = Err -> Err
    end.

-spec deployment_namespace(binary()) -> {ok, binary()} | {error, term()}.
deployment_namespace(Name) ->
    Path = <<"/apis/apps/v1/deployments?fieldSelector=metadata.name%3D", Name/binary>>,
    case get_json(Path) of
        {ok, #{<<"items">> := [#{<<"metadata">> := #{<<"namespace">> := Namespace}} | _]}} ->
            {ok, Namespace};
        {ok, #{<<"items">> := []}} ->
            {error, {not_found, Name}};
        {ok, Other} ->
            {error, {unexpected_body, Other}};
        {error, _} = Err ->
            Err
    end.

-spec pod_logs(binary(), pos_integer()) -> {ok, binary()} | {error, term()}.
pod_logs(App, Lines) ->
    case app_pod(App) of
        {error, _} = Err ->
            Err;
        {ok, #{namespace := Namespace, name := Name}} ->
            Path = <<
                "/api/v1/namespaces/",
                Namespace/binary,
                "/pods/",
                Name/binary,
                "/log?tailLines=",
                (integer_to_binary(Lines))/binary
            >>,
            get_raw(Path)
    end.

-spec deployment_status(binary(), binary()) -> {ok, rollout()} | {error, term()}.
deployment_status(Namespace, Name) ->
    Path = <<"/apis/apps/v1/namespaces/", Namespace/binary, "/deployments/", Name/binary>>,
    case get_json(Path) of
        {ok, #{<<"spec">> := Spec, <<"status">> := Status}} ->
            {ok, #{
                desired => maps:get(<<"replicas">>, Spec, 1),
                updated => maps:get(<<"updatedReplicas">>, Status, 0),
                ready => maps:get(<<"readyReplicas">>, Status, 0)
            }};
        {ok, Other} ->
            {error, {unexpected_body, Other}};
        {error, _} = Err ->
            Err
    end.

-spec restart_deployment(binary(), binary()) -> ok | {error, term()}.
restart_deployment(Namespace, Name) ->
    Now = calendar:system_time_to_rfc3339(erlang:system_time(second), [{offset, "Z"}]),
    Patch = #{
        <<"spec">> => #{
            <<"template">> => #{
                <<"metadata">> => #{
                    <<"annotations">> => #{
                        <<"botesito.io/restartedAt">> => list_to_binary(Now)
                    }
                }
            }
        }
    },
    Path = <<"/apis/apps/v1/namespaces/", Namespace/binary, "/deployments/", Name/binary>>,
    case patch(Path, Patch) of
        {ok, _} -> ok;
        {error, _} = Err -> Err
    end.

app_pod(App) ->
    case labelled_pod(App) of
        {ok, _} = Found -> Found;
        {error, {not_found, _}} -> named_pod(App);
        {error, _} = Err -> Err
    end.

labelled_pod(App) ->
    Path = <<
        "/api/v1/pods?limit=1&labelSelector=app.kubernetes.io/name%3D",
        App/binary
    >>,
    case get_json(Path) of
        {ok, #{<<"items">> := [Item | _]}} -> {ok, pod_info(Item)};
        {ok, #{<<"items">> := []}} -> {error, {not_found, App}};
        {ok, Other} -> {error, {unexpected_body, Other}};
        {error, _} = Err -> Err
    end.

named_pod(App) ->
    case deployment_namespace(App) of
        {error, _} = Err ->
            Err;
        {ok, Namespace} ->
            Path = <<"/api/v1/namespaces/", Namespace/binary, "/pods">>,
            case get_json(Path) of
                {ok, #{<<"items">> := Items}} ->
                    Pods = [pod_info(Item) || Item <- Items],
                    case [P || #{name := Name} = P <- Pods, is_app_pod(Name, App)] of
                        [] -> {error, {not_found, App}};
                        [Pod | _] -> {ok, Pod}
                    end;
                {ok, Other} ->
                    {error, {unexpected_body, Other}};
                {error, _} = Err ->
                    Err
            end
    end.

is_app_pod(PodName, App) ->
    Size = byte_size(App),
    case PodName of
        <<App:Size/binary, "-", _/binary>> -> true;
        App -> true;
        _ -> false
    end.

node_info(#{<<"metadata">> := #{<<"name">> := Name}} = Item) ->
    Conditions = maps:get(<<"conditions">>, maps:get(<<"status">>, Item, #{}), []),
    Ready =
        case [S || #{<<"type">> := <<"Ready">>, <<"status">> := S} <- Conditions] of
            [<<"True">> | _] -> <<"Ready">>;
            [Other | _] -> Other;
            [] -> <<"Unknown">>
        end,
    #{name => Name, ready => Ready}.

pod_info(#{<<"metadata">> := Metadata} = Item) ->
    Status = maps:get(<<"status">>, Item, #{}),
    Statuses = maps:get(<<"containerStatuses">>, Status, []),
    ReadyCount = length([S || #{<<"ready">> := true} = S <- Statuses]),
    #{
        namespace => maps:get(<<"namespace">>, Metadata, <<"default">>),
        name => maps:get(<<"name">>, Metadata),
        phase => maps:get(<<"phase">>, Status, <<"Unknown">>),
        ready => <<
            (integer_to_binary(ReadyCount))/binary,
            "/",
            (integer_to_binary(length(Statuses)))/binary
        >>
    }.

get_json(Path) ->
    case get_raw(Path) of
        {ok, Body} -> decode(Body);
        {error, _} = Err -> Err
    end.

get_raw(Path) ->
    request(fun nhttpc:get/2, url(Path), no_body).

patch(Path, Payload) ->
    Body = iolist_to_binary(json:encode(Payload)),
    Headers = [{<<"content-type">>, <<"application/strategic-merge-patch+json">>}],
    case request(fun(Url, Opts) -> nhttpc:patch(Url, Body, Opts) end, url(Path), Headers) of
        {ok, Raw} -> decode(Raw);
        {error, _} = Err -> Err
    end.

request(Fun, Url, HeadersOrNoBody) ->
    case token() of
        {error, _} = Err ->
            Err;
        {ok, Token} ->
            Headers =
                [{<<"authorization">>, <<"Bearer ", Token/binary>>}] ++
                    case HeadersOrNoBody of
                        no_body -> [{<<"accept">>, <<"application/json">>}];
                        Extra -> Extra
                    end,
            Opts = #{
                body_to => {fold, fun(Chunk, Acc) -> {continue, [Chunk | Acc]} end},
                fold_init => [],
                tls => #{cacertfile => ca_cert_file(), verify => verify_peer},
                headers => Headers,
                timeouts => #{request => 15000}
            },
            handle_response(Fun(Url, Opts))
    end.

url(Path) ->
    Host = list_to_binary(api_host()),
    <<"https://", Host/binary, Path/binary>>.

handle_response({ok, #{status := Status, body := {fold, Chunks}}}) when
    Status >= 200, Status < 300
->
    {ok, iolist_to_binary(lists:reverse(Chunks))};
handle_response({ok, #{status := Status, body := {fold, Chunks}}}) ->
    {error, {k8s_error, Status, reason(iolist_to_binary(lists:reverse(Chunks)))}};
handle_response({ok, #{status := Status, body := Body}}) when Status >= 200, Status < 300 ->
    {ok, iolist_to_binary(Body)};
handle_response({ok, #{status := Status, body := Body}}) ->
    {error, {k8s_error, Status, reason(iolist_to_binary(Body))}};
handle_response({error, _} = Err) ->
    Err.

reason(Body) ->
    case decode(Body) of
        {ok, #{<<"message">> := Message}} -> Message;
        _ -> Body
    end.

ca_cert_file() ->
    filename:join(service_account_dir(), "ca.crt").

token() ->
    Path = filename:join(service_account_dir(), "token"),
    case file:read_file(Path) of
        {ok, Token} -> {ok, string:trim(Token)};
        {error, Reason} -> {error, {no_service_account_token, Path, Reason}}
    end.

decode(Body) ->
    try json:decode(Body) of
        Json -> {ok, Json}
    catch
        error:Reason -> {error, {decode_error, Reason}}
    end.
