import unittest

from main import DEFAULT_SYSTEM_PROMPT, _extract_prompt, strip_trailing_tool_use


class ExtractPromptTests(unittest.TestCase):
    def test_plain_prompt_string(self):
        self.assertEqual(
            _extract_prompt({"prompt": "responsive pricing cards"}),
            "responsive pricing cards",
        )

    def test_rejects_non_object_payload(self):
        with self.assertRaises(ValueError):
            _extract_prompt("not-an-object")

    def test_rejects_non_string_prompt(self):
        with self.assertRaises(ValueError):
            _extract_prompt({"prompt": ["list"]})

    def test_messages_passthrough_without_tool_use(self):
        messages = [{"role": "user", "content": [{"text": "hello"}]}]
        self.assertEqual(_extract_prompt({"messages": messages}), messages)

    def test_strips_trailing_tool_use(self):
        messages = [
            {"role": "user", "content": [{"text": "hello"}]},
            {"role": "assistant", "content": [{"toolUse": {"name": "x"}}]},
        ]
        cleaned = strip_trailing_tool_use(messages)
        self.assertEqual(cleaned, [{"role": "user", "content": [{"text": "hello"}]}])


class SystemPromptTests(unittest.TestCase):
    def test_requires_html_css_js_blocks(self):
        prompt = DEFAULT_SYSTEM_PROMPT.lower()
        self.assertIn("html", prompt)
        self.assertIn("css", prompt)
        self.assertIn("javascript", prompt)
        self.assertIn("vanilla", prompt)


if __name__ == "__main__":
    unittest.main()
