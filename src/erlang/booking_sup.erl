-module(booking_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link(?MODULE, []).

init([]) ->
    Worker = #{
        id => booking_worker,
        start => {booking_worker, start_link, []},
        restart => permanent
    },
    {ok, {#{strategy => one_for_one}, [Worker]}}.
