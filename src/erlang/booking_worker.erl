-module(booking_worker).
-export([start/0, start_link/0]).

start() ->
    spawn(fun loop/0).

start_link() ->
    {ok, spawn_link(fun loop/0)}.

loop() ->
    receive
        {book, Caller, RequestId} ->
            Caller ! {booking_reply, RequestId, test_only},
            loop();
        stop ->
            ok
    end.