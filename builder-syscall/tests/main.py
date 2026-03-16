"""
Главный запускатель всех интеграционных тестов.
Запуск: python3 tests/main.py  (из папки builder-syscall/)
Возвращает exit code 0 при успехе, 1 при провале.

Чтобы добавить новые тесты:
1. Создать tests/test_<feature>.py с классом unittest.TestCase
2. Импортировать класс ниже и добавить его в suite
"""
import sys
import os
import unittest

# Добавляем папку tests/ в path для импортов внутри тестов
sys.path.insert(0, os.path.dirname(__file__))

from test_boot import TestBoot
from test_commands import TestCommands


def main():
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestBoot))
    suite.addTests(loader.loadTestsFromTestCase(TestCommands))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
