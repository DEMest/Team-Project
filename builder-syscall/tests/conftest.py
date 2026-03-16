import sys
import os

# Добавляем папку tests/ в sys.path чтобы pytest мог импортировать qemu_wrapper
sys.path.insert(0, os.path.dirname(__file__))
