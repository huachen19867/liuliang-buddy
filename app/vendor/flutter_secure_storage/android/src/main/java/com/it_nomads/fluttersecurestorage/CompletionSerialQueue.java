package com.it_nomads.fluttersecurestorage;

import java.util.ArrayDeque;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/** Process-wide scheduling primitive: completion, not dispatch return, advances FIFO. */
final class CompletionSerialQueue {
    private final Executor executor;
    private final ArrayDeque<Consumer<Runnable>> pending = new ArrayDeque<>();
    private boolean active;

    CompletionSerialQueue(Executor executor) { this.executor = executor; }

    synchronized void submit(Consumer<Runnable> operation) {
        pending.addLast(operation);
        if (!active) dispatchNext();
    }

    private synchronized void dispatchNext() {
        Consumer<Runnable> operation = pending.pollFirst();
        if (operation == null) { active = false; return; }
        active = true;
        AtomicBoolean completed = new AtomicBoolean();
        executor.execute(() -> operation.accept(() -> {
            if (completed.compareAndSet(false, true)) dispatchNext();
        }));
    }
}
