#!/bin/bash

set -e

(
  echo "src hex1.hex0"
  cat hex1_riscv64.hex0
  printf '\0'

  echo "src hex2.hex1"
  cat hex2_riscv64.hex1
  printf '\0'

  echo "src M0.hex2"
  cat M0_riscv64.hex2
  printf '\0'

  echo "src testA.hex0"
  cat hello_hex0.hex0
  printf '\0'

  echo "src testB.hex1"
  cat hello_hex1.hex1
  printf '\0'

  echo "src testC.hex2"
  cat hello_hex2.hex2
  printf '\0'

  echo "src testD.M0"
  cat hello_m0.M0
  printf '\0'
) > files.pl

mv files.pl ..