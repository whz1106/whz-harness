import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("daily_work_journal.py")


def run_cmd(*args, env=None):
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        ["python3", str(SCRIPT), *args],
        check=False,
        text=True,
        capture_output=True,
        env=merged_env,
    )


class DailyWorkJournalTests(unittest.TestCase):
    def test_daily_summary_merges_raw_logs_and_redacts_secrets(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"DAILY_WORK_JOURNAL": tmp}
            result = run_cmd(
                "append-raw",
                "--date",
                "2026-05-25",
                "--agent-file",
                "mac-codex-project.md",
                "--project",
                "项目 A",
                "--entry",
                "完成 API 调试，token=abc1234567890abcdef",
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            result = run_cmd("daily", "--date", "2026-05-25", env=env)
            self.assertEqual(result.returncode, 0, result.stderr)

            daily = Path(tmp, "2026", "2026-05", "daily", "2026-05-25.md").read_text()
            self.assertIn("# 2026-05-25 今日工作总结", daily)
            self.assertIn("项目 A", daily)
            self.assertIn("完成 API 调试", daily)
            self.assertNotIn("abc1234567890abcdef", daily)
            self.assertIn("[REDACTED]", daily)

    def test_daily_summary_appends_flexible_work_details_after_tomorrow_advice(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"DAILY_WORK_JOURNAL": tmp}
            result = run_cmd(
                "append-raw",
                "--date",
                "2026-05-25",
                "--agent-file",
                "mac-codex-benchmark.md",
                "--project",
                "模型性能测试",
                "--entry",
                "参数：batch=8, context=32000\n测试结果：吞吐 42 tok/s，首字延迟 1.2s\n明日建议：继续测试 batch=16",
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            result = run_cmd("daily", "--date", "2026-05-25", env=env)
            self.assertEqual(result.returncode, 0, result.stderr)

            daily = Path(tmp, "2026", "2026-05", "daily", "2026-05-25.md").read_text()
            self.assertIn("## 明日建议", daily)
            self.assertIn("## 工作记录详情", daily)
            self.assertLess(
                daily.index("## 明日建议"),
                daily.index("## 工作记录详情"),
            )
            detail_section = daily.split("## 工作记录详情", 1)[1]
            self.assertIn("模型性能测试", detail_section)
            self.assertIn("参数：batch=8, context=32000", detail_section)
            self.assertIn("测试结果：吞吐 42 tok/s", detail_section)
            self.assertNotIn("### 来源：", detail_section)

    def test_monthly_summary_reads_daily_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            daily_dir = Path(tmp, "2026", "2026-05", "daily")
            daily_dir.mkdir(parents=True)
            daily_dir.joinpath("2026-05-25.md").write_text(
                "# 2026-05-25 今日工作总结\n\n## 核心进展\n- 完成日志 skill\n",
                encoding="utf-8",
            )

            result = run_cmd("monthly", "--month", "2026-05", env={"DAILY_WORK_JOURNAL": tmp})
            self.assertEqual(result.returncode, 0, result.stderr)

            monthly = Path(tmp, "2026", "2026-05", "monthly-summary.md").read_text()
            self.assertIn("# 2026-05 月度工作总结", monthly)
            self.assertIn("完成日志 skill", monthly)


if __name__ == "__main__":
    unittest.main()
