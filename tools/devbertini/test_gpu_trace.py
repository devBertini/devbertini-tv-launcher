# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Tests of gpu_trace.py's reading of an atrace dump: slices pair up per thread, the app's frames and SurfaceFlinger's
compositions are timed only where they had the GPU alone, and the medians add up to the time per frame.

    python -B tools/devbertini/test_gpu_trace.py
"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("gpu_trace", pathlib.Path(__file__).with_name("gpu_trace.py"))
gpu_trace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu_trace)


def mark(thread, tid, tgid, seconds, body):
    return f"  {thread}-{tid}   ( {tgid}) [002] ..... {seconds:.6f}: tracing_mark_write: {body}"


# App 4242 queues frame A at 0.000 (done 0.017) and frame B at 0.018 (done 0.040); SurfaceFlinger (545) queues a
# composition at 0.020 (done 0.025), inside B, and another at 0.050 (done 0.0545), alone. Alone: A 17 ms, the second
# composition 4.5 ms; B and the first composition shared the GPU.
TRACE = "\n".join([
    "# tracer: nop",
    mark("GPU completion", 4300, 4242, 0.000, "B|4242|waiting for GPU completion 0"),
    mark("GPU completion", 4300, 4242, 0.001, "B|4242|waitForever"),
    mark("GPU completion", 4300, 4242, 0.016, "E|4242"),
    mark("GPU completion", 4300, 4242, 0.017, "E|4242"),
    mark("1.raster", 4250, 4242, 0.016, "B|4242|eglSwapBuffers"),
    mark("GPU completion", 4300, 4242, 0.018, "B|4242|waiting for GPU completion 1"),
    mark("1.raster", 4250, 4242, 0.018, "E|4242"),
    mark("RE Completion", 600, 545, 0.020, "B|545|waiting for RE Completion 7"),
    mark("RE Completion", 600, 545, 0.025, "E|545"),
    mark("GPU completion", 4300, 4242, 0.040, "E|4242"),
    mark("RE Completion", 600, 545, 0.050, "B|545|waiting for RE Completion 8"),
    mark("RE Completion", 600, 545, 0.0545, "E|545"),
    mark("GPU completion", 9900, 9800, 0.030, "B|9800|waiting for GPU completion 3"),
    mark("GPU completion", 9900, 9800, 0.031, "E|9800"),
    "  surfaceflinger-545   (  545) [001] ..... 0.050000: sched_switch: prev_comm=x",
])


class SlicesTest(unittest.TestCase):
    def test_nested_slices_close_innermost_first(self):
        names = [s[3] for s in gpu_trace.slices(TRACE) if s[2] == "4242"]
        self.assertIn("waitForever", names)
        outer = [s for s in gpu_trace.slices(TRACE) if s[3] == "waiting for GPU completion 0"][0]
        self.assertAlmostEqual(outer[5] - outer[4], 0.017)


class GpuJobsTest(unittest.TestCase):
    def test_jobs_in_order_of_queueing(self):
        jobs = gpu_trace.gpu_jobs(gpu_trace.slices(TRACE), 4242)
        self.assertEqual([kind for kind, *_ in jobs], ["app", "app", "sf", "sf"])

    def test_only_jobs_that_had_the_gpu_alone_are_timed(self):
        timed = gpu_trace.alone(gpu_trace.gpu_jobs(gpu_trace.slices(TRACE), 4242))
        self.assertEqual(timed, [("app", 17.0), ("sf", 4.5)])

    def test_another_apps_frames_are_left_out(self):
        jobs = gpu_trace.gpu_jobs(gpu_trace.slices(TRACE), 9800)
        self.assertEqual([kind for kind, *_ in jobs], ["sf", "app", "sf"])


class SummarizeTest(unittest.TestCase):
    def test_per_frame_is_the_two_medians_and_the_budget_decides(self):
        run = gpu_trace.gpu_jobs(gpu_trace.slices(TRACE), 4242)
        result = gpu_trace.summarize([run, run])
        self.assertEqual(result["frames"], 4)
        self.assertEqual(result["app"]["jobs"], 2)
        self.assertEqual(result["app"]["p50_ms"], 17.0)
        self.assertEqual(result["surfaceflinger"]["p50_ms"], 4.5)
        self.assertEqual(result["per_frame_ms"], 21.5)
        self.assertFalse(result["fits_60hz"])

    def test_runs_are_judged_apart(self):
        # The same jobs as two runs: a job of one run never overlaps a job of the other.
        run = gpu_trace.gpu_jobs(gpu_trace.slices(TRACE), 4242)
        self.assertEqual(gpu_trace.summarize([run, run])["app"]["jobs"], 2)

    def test_no_jobs(self):
        self.assertEqual(gpu_trace.summarize([])["app"], {"jobs": 0})


if __name__ == "__main__":
    unittest.main()
