package cn.liuliang.liuliang_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackgroundRefreshScheduleTest {
    @Test
    fun foregroundEntryPermanentlyInvalidatesExistingBackgroundRun() {
        val started = BackgroundRefreshSchedule.currentRevision()
        assertTrue(BackgroundRefreshSchedule.isCurrent(started))
        BackgroundRefreshSchedule.invalidateRunningTask()
        assertFalse(BackgroundRefreshSchedule.isCurrent(started))
        // Returning to the background must not make the stale revision valid.
        assertTrue(BackgroundRefreshSchedule.isCurrent(BackgroundRefreshSchedule.currentRevision()))
        assertFalse(BackgroundRefreshSchedule.isCurrent(started))
    }
}
