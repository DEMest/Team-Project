import unittest
from qemu_wrapper import QEMUInstance


class TestBoot(unittest.TestCase):
    """Проверяет корректную загрузку образа в QEMU."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()

    def tearDown(self):
        self.qemu.stop()

    def test_stage1_boot_message(self):
        """Загрузчик (boot.S) выводит приветствие первого этапа."""
        self.qemu.expect(r'\[BOOTED\]: Stage 1')

    def test_stage1_jump_message(self):
        """Загрузчик сообщает о переходе ко второму этапу."""
        self.qemu.expect(r'\[BUILDED\]: Jump to stage 2')

    def test_stage2_boot_message(self):
        """Simon выводит приветствие второго этапа."""
        self.qemu.expect(r'\[BOOTED\]: Stage 2 \(simon\)')

    def test_prompt_appears(self):
        """После загрузки появляется командный промпт."""
        self.qemu.expect(r'Simon says~')
