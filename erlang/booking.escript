#!/usr/bin/env escript

main([Mode]) when Mode =:= "start"; Mode =:= "test" ->
    SourceDir = filename:dirname(filename:absname(escript:script_name())),
    compile_and_load(SourceDir, booking_worker),
    compile_and_load(SourceDir, booking_sup),
    {ok, Supervisor} = booking_sup:start_link(),
    run(Mode, Supervisor);
main(_) ->
    io:format(standard_error, "Usage: escript booking.escript start|test~n", []),
    halt(2).

compile_and_load(SourceDir, Module) ->
    Source = filename:join(SourceDir, atom_to_list(Module) ++ ".erl"),
    {ok, Module, Binary} = compile:file(Source, [binary, report]),
    {module, Module} = code:load_binary(Module, Source, Binary).

run("start", Supervisor) ->
    Monitor = erlang:monitor(process, Supervisor),
    io:format("Booking supervisor and worker started. Press Ctrl+C to stop.~n"),
    receive
        {'DOWN', Monitor, process, Supervisor, Reason} ->
            error({supervisor_stopped, Reason})
    end;
run("test", Supervisor) ->
    [{booking_worker, Original, worker, _}] = supervisor:which_children(Supervisor),
    check_reply(Original, 101),
    exit(Original, kill),
    Deadline = erlang:monotonic_time(millisecond) + 5000,
    Replacement = wait_for_replacement(Supervisor, Original, Deadline),
    check_reply(Replacement, 102),
    io:format("PASS: booking replies preserved request IDs before and after the restart.~n").

check_reply(Worker, RequestId) ->
    Worker ! {book, self(), RequestId},
    receive
        {booking_reply, RequestId, test_only} ->
            ok
    after 2000 ->
        error({booking_reply_timeout, RequestId})
    end.

wait_for_replacement(Supervisor, Original, Deadline) ->
    case supervisor:which_children(Supervisor) of
        [{booking_worker, Pid, worker, _}] when is_pid(Pid), Pid =/= Original ->
            Pid;
        _ ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true ->
                    timer:sleep(25),
                    wait_for_replacement(Supervisor, Original, Deadline);
                false ->
                    error(worker_did_not_restart)
            end
    end.
