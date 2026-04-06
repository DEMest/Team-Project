import unittest
from qemu_wrapper import QEMUInstance


class TestCommands(unittest.TestCase):
    """Проверяет базовые команды Simon."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()
        self.qemu.expect(r'Simon says~')

    def tearDown(self):
        self.qemu.stop()

    def test_echo_command(self):
        """Неизвестная команда возвращается с префиксом 'echo answered'."""
        self.qemu.send('hello')
        self.qemu.expect('echo answered hello')

    def test_prompt_reappears_after_command(self):
        """После команды промпт появляется снова."""
        self.qemu.send('hello')
        self.qemu.expect(r'Simon says~')

    def test_shutdown_command(self):
        """Команда shutdown завершает QEMU."""
        self.qemu.send('shutdown')
        self.qemu.expect_eof(timeout=5)

    def test_reboot_command(self):
        """Команда reboot перезагружает систему."""
        self.qemu.send('reboot')
        self.qemu.expect(r'Stage 1', timeout=5)

    def test_ls_command(self):
        """Команда ls показывает файлы файловой системы."""
        self.qemu.send('ls')
        self.qemu.expect(r'Simon says~')


class TestHex0(unittest.TestCase):
    """Проверяет компиляцию и запуск hex0 файлов."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()
        self.qemu.expect(r'Simon says~')

    def tearDown(self):
        self.qemu.stop()

    def test_hex0_compile(self):
        """Команда hex0 компилирует payload.hex0 без ошибок."""
        self.qemu.send('hex0 payload.hex0')
        self.qemu.expect('Done.')

    def test_hex0_run(self):
        """Скомпилированный payload.hex0 выводит Hello, World!"""
        self.qemu.send('hex0 payload.hex0')
        self.qemu.expect('Done.')
        self.qemu.send('do payload.hex0.bin')
        self.qemu.expect('Hello, World!')


class TestHex1(unittest.TestCase):
    """Проверяет компиляцию и запуск hex1 файлов."""

    def setUp(self):
        self.qemu = QEMUInstance()
        self.qemu.start()
        self.qemu.expect(r'Simon says~')

    def tearDown(self):
        self.qemu.stop()

    def test_hex1_compile(self):
        """Команда hex1 компилирует payload.hex1 без ошибок."""
        self.qemu.send('hex1 payload.hex1')
        self.qemu.expect('Done.')

    def test_hex1_run(self):
        """Скомпилированный payload.hex1 выводит Hello, World!"""
        self.qemu.send('hex1 payload.hex1')
        self.qemu.expect('Done.')
        self.qemu.send('do payload.hex1.bin')
        self.qemu.expect('Hello, World!')

