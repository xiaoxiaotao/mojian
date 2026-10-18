package com.desktodo.app;

/** UI-thread revisions: an older network reply cannot acknowledge newer edits. */
final class EditRevision {
    private long current;
    private long acknowledged;

    void edited() { current++; }
    long snapshot() { return current; }
    boolean acknowledge(long sent) {
        if (sent < 0 || sent > current) throw new IllegalArgumentException("Unknown revision");
        if (sent < acknowledged) return false;
        acknowledged = sent;
        return sent == current;
    }
}
