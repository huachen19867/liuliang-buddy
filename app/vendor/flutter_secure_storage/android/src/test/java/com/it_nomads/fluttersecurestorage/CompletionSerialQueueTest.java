package com.it_nomads.fluttersecurestorage;

import org.junit.Test;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.Assert.*;

public class CompletionSerialQueueTest {
    private static final class Worker implements Executor {
        final ArrayDeque<Runnable> tasks = new ArrayDeque<>();
        public void execute(Runnable task) { tasks.add(task); }
        void drain() { while (!tasks.isEmpty()) tasks.remove().run(); }
    }

    @Test public void asyncInitializationAndWriteHoldSlotUntilActualCompletion() {
        Worker worker = new Worker();
        CompletionSerialQueue queue = new CompletionSerialQueue(worker);
        List<String> events = new ArrayList<>();
        AtomicReference<Runnable> finishWrite = new AtomicReference<>();
        queue.submit(done -> { events.add("background initialize"); finishWrite.set(done); });
        queue.submit(done -> { events.add("foreground delete"); done.run(); });
        worker.drain();
        // Returning from dispatch, a UI timeout or detaching an engine does not
        // signal completion; foreground deletion must still wait for encryption.
        assertEquals(List.of("background initialize"), events);
        events.add("background write committed");
        finishWrite.get().run();
        worker.drain();
        assertEquals(List.of("background initialize", "background write committed", "foreground delete"), events);
    }

    @Test public void expiredQueuedOwnerCannotWriteAfterForegroundClear() {
        Worker worker = new Worker();
        CompletionSerialQueue queue = new CompletionSerialQueue(worker);
        AtomicBoolean current = new AtomicBoolean(true);
        AtomicReference<Runnable> finish = new AtomicReference<>();
        AtomicReference<String> stored = new AtomicReference<>("old");
        queue.submit(finish::set);
        queue.submit(done -> { if (current.get()) stored.set("late background"); done.run(); });
        queue.submit(done -> { stored.set(null); done.run(); });
        worker.drain();
        current.set(false);
        finish.get().run();
        worker.drain();
        assertNull(stored.get());
    }

    @Test public void duplicateCallbackCannotReleaseFollowingOperation() {
        Worker worker = new Worker();
        CompletionSerialQueue queue = new CompletionSerialQueue(worker);
        AtomicReference<Runnable> first = new AtomicReference<>();
        AtomicReference<Runnable> second = new AtomicReference<>();
        AtomicBoolean thirdRan = new AtomicBoolean();
        queue.submit(first::set);
        queue.submit(second::set);
        queue.submit(done -> { thirdRan.set(true); done.run(); });
        worker.drain();
        first.get().run();
        worker.drain();
        first.get().run();
        worker.drain();
        assertFalse(thirdRan.get());
        second.get().run();
        worker.drain();
        assertTrue(thirdRan.get());
    }
}
