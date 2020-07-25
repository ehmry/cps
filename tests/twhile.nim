import std/unittest

import cps
import cps/eventqueue

proc adder(x: var int) =
  inc x

suite "cps":

  setup:
    var cup: int

  test "while":
    proc foo(): Cont {.cps.} =
      var i: int = 0
      while i < 2:
        let x: int = i
        adder(i)
        assert x < i
        check x < i
      cup = i
      check cup == 2
    discard foo()