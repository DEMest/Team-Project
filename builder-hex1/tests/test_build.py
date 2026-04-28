import unittest
import subprocess
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')


class TestMakeBuild(unittest.TestCase):
    """Проверяет что make собирает образ без ошибок."""

    def test_make_builds_image(self):
        """make all завершается успешно."""
        result = subprocess.run(
            ['make', 'all'],
            cwd=ROOT, capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

    def test_image_exists(self):
        """image_qemu.bin создаётся после сборки."""
        image = os.path.join(ROOT, 'image_qemu.bin')
        self.assertTrue(os.path.exists(image), 'image_qemu.bin не найден')

    def test_image_not_empty(self):
        """image_qemu.bin не пустой."""
        image = os.path.join(ROOT, 'image_qemu.bin')
        self.assertGreater(os.path.getsize(image), 0)

    def test_no_temp_files_after_build(self):
        """Временные файлы удаляются после сборки."""
        for name in ['boot.elf', 'boot.bin', 'simon.elf', 'simon.bin', 'simon.hex0', 'simon.hex1', 'payload.hex0.bin', 'payload.hex1.bin']:
            path = os.path.join(ROOT, name)
            self.assertFalse(os.path.exists(path), f'{name} не был удалён')
