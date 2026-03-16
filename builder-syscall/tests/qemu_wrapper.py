import os
import pexpect

IMAGE_PATH = os.path.join(os.path.dirname(__file__), '..', 'image_qemu.bin')
QEMU_CMD = 'qemu-system-riscv64 -machine virt -nographic -bios {image}'
BOOT_TIMEOUT = 15


class QEMUInstance:
    """Обёртка над QEMU для интерактивных тестов через pexpect."""

    def __init__(self, image_path=None, timeout=BOOT_TIMEOUT):
        self.image_path = image_path or IMAGE_PATH
        self.timeout = timeout
        self.child = None
        self._log = []

    def start(self):
        cmd = QEMU_CMD.format(image=self.image_path)
        self._log.append(f'$ {cmd}\n')
        self.child = pexpect.spawn(cmd, timeout=self.timeout, encoding='utf-8')
        return self

    def expect(self, pattern, timeout=None):
        """Ждёт появления паттерна в выводе QEMU."""
        t = timeout if timeout is not None else self.timeout
        self.child.expect(pattern, timeout=t)
        before = self.child.before or ''
        after = self.child.after or ''
        self._log.append(before + after)

    def expect_eof(self, timeout=5):
        """Ждёт завершения процесса QEMU (EOF)."""
        self.child.expect(pexpect.EOF, timeout=timeout)
        if self.child.before:
            self._log.append(self.child.before)

    def send(self, text):
        """Отправляет строку + Enter в stdin QEMU."""
        self._log.append(f'\n>>> {text}\n')
        self.child.sendline(text)

    def get_output(self):
        """Возвращает накопленный лог взаимодействия с QEMU."""
        return ''.join(self._log)

    def stop(self):
        if self.child and self.child.isalive():
            self.child.terminate(force=True)
            self.child.wait()
