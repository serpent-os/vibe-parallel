/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * vibe.parallel
 *
 * Fiber-based parallel support
 *
 * Provides syntax sugar to run fibers from within a foreach loop
 *
 * Notes: These APIs are intended for use with vibe.d which provides asynchronous I/O
 * and fiber multiplexing.
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module vibe.parallel;

import core.time;
import std.algorithm : map, each;
import std.range : isInputRange, ElementType, iota;
import vibe.core.channel;
import vibe.core.core;
import std.exception : assumeWontThrow;

@safe:

/**
 * Test (visual feedback) all requested coroutines are running with random sleeps
 */
private unittest
{
    import std.conv : to;
    import std.stdio : writefln;

    enum fiberWorkers = 100;
    enum maxTaskTime = 200; /* msecs */
    enum tasks = 5_000;

    auto items = iota(0, tasks).map!(i => i.to!string);

    writefln!"Simulating %d tasks with random time-to-completion, handled sequentially by %d fiber workers:"(tasks,
            fiberWorkers);
    writefln!"%s\t%s\t%s"("Task", "Fiber", "Task time");
    /* Assert we CAN check out items */
    foreach (l, idx; items.fiberParallel(fiberWorkers))
    {
        import std.random : Random, unpredictableSeed, uniform;

        auto rnd = Random(unpredictableSeed);
        auto taskTime = (cast(int)(uniform(0.0, 1.0, rnd) * maxTaskTime)).msecs;
        /* simulated task time-to-completion */
        imported!"vibe.core.core".sleep(taskTime);
        writefln!"%4s:\t%3s\t%s"(l, idx, taskTime);
    }
}

/**
 * Iterate over items in range using fibers
 *
 * Examples:
 * ---
 * foreach (dl, fiberIndex; downloads.fiberParallel)
 * {
 *      dl.download();
 * }
 * ---
 *
 * Params:
 *   input = Some valid input range
 *   maxRoutines = How many coroutines to spawn to consume the range
 * Returns: A foreach-capable type
 */
public auto fiberParallel(Range)(Range input, ulong maxRoutines = 16)
        if (isInputRange!Range)
{
    static struct ForeachFiber(Range)
    {
        alias Item = ElementType!Range;

        /**
         * Provide foreach semantics
         *
         * Params:
         *   dg = Delegate to call
         * Returns:
         */
        int opApply(scope int delegate(ref Item, ulong routineIndex) dg) @trusted
        {
            /* All coroutines will pull from the channel */
            Channel!Item pumper = createChannel!Item;

            auto routines = iota(maxRoutines).map!(i => runTask(&routineRunnable, pumper, i, dg));

            /* Lazy mapped, so start them */
            routines.each!((r) {});

            runTask({
                foreach (ref item; data)
                {
                    assumeWontThrow(pumper.put(item));
                }
                pumper.close();
            });
            routines.each!((r) => r.join);
            return 0;
        }

    private:

        static void routineRunnable(Channel!Item pumper, ulong routineIndex,
                scope int delegate(ref Item, ulong routineIndex) dg) nothrow
        {
            Item currentItem;
            assumeWontThrow({
                while (pumper.tryConsumeOne(currentItem))
                {
                    dg(currentItem, routineIndex);
                }
            }());
        }

        Range data;
        /* this is passed a default arg value via fiberParallel so only needs to be declared here */
        ulong maxRoutines;
    }

    return ForeachFiber!Range(input, maxRoutines);
}
