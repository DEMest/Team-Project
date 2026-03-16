import unittest
from qemu_wrapper import QEMUInstance


class TestBoot(unittest.TestCase):
    """Проверяет корректную загрузку образа в QEMU."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()

    def tearDown(self):
        self.qemu.stop()

    def test_boot_message(self):
        """Загрузчик выводит приветствие с идентификатором команды."""
        self.qemu.expect('coded by Team 42')

    def test_prompt_appears(self):
        """После загрузки появляется командный промпт."""
        self.qemu.expect(r'Simon says~')
