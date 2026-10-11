"""CI 脚本的静态检查：macOS 自带 bash 3.2 会把紧跟在 $变量 后面的非 ASCII 字符（如全角括号）读进变量名，
在 set -u 下报 unbound variable（D-05、D-12）。变量后紧跟中文/全角字符时必须写成 ${变量}。"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNSAFE = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)[^\x00-\x7F]")


class CIScriptTests(unittest.TestCase):
    def test_no_bare_variable_followed_by_non_ascii(self):
        files = sorted((ROOT / "ci").glob("*.sh")) + sorted((ROOT / ".github" / "workflows").glob("*.yml"))
        self.assertTrue(files)
        bad = []
        for path in files:
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if UNSAFE.search(line):
                    bad.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
        self.assertEqual(bad, [], "use ${name} before non-ASCII text")

    def test_release_check_does_not_pipe_into_grep_q(self):
        # D-11：pipefail 下 `cmd | grep -q` 命中时会因 SIGPIPE 被判为失败
        text = (ROOT / "ci" / "check-release-binary.sh").read_text(encoding="utf-8")
        code = [line for line in text.splitlines() if not line.lstrip().startswith("#")]
        self.assertEqual([line for line in code if re.search(r"\|\s*grep -q", line)], [])


if __name__ == "__main__":
    unittest.main()
