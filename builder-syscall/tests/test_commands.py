import unittest
from qemu_wrapper import QEMUInstance


class TestCommands(unittest.TestCase):
    """Проверяет команды интерактивной оболочки Simon."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()
        # Ждём промпт перед каждым тестом
        self.qemu.expect(r'Simon says~')

    def tearDown(self):
        self.qemu.stop()

    def test_echo_command(self):
        """Неизвестная команда возвращается с префиксом 'echo answered'."""
        self.qemu.send('hello')
        self.qemu.expect('echo answered hello')

    def test_echo_multiple_words(self):
        """Echo работает для строк с пробелами."""
        self.qemu.send('hello world')
        self.qemu.expect('echo answered hello world')

    def test_prompt_reappears_after_command(self):
        """После команды промпт появляется снова."""
        self.qemu.send('hello')
        self.qemu.expect(r'Simon says~')

    def test_shutdown_command(self):
        """Команда shutdown завершает QEMU (EOF в stdout)."""
        self.qemu.send('shutdown')
        self.qemu.expect_eof(timeout=5)
