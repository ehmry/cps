var r = 0

type
  C = ref object
    fn: proc (c: C): C {.nimcall.}
    e: ref CatchableError
    x1: ref CatchableError
    x2: ref CatchableError
  CpsException = CatchableError

proc noop(c: C): C =
  echo "noop"
  c

proc f2(c: C): C =
  ## finally from the "toplevel" try

  # we look for non-nil exceptions
  if not c.x2.isNil:
    # it's code that's inside a try
    setCurrentException c.x2 # added boilerplate
  elif not c.x1.isNil:
    # it's code that's inside a try
    setCurrentException c.x1 # added boilerplate
  elif not c.e.isNil:
    # finally when exception was thrown
    setCurrentException c.e # added boilerplate

  inc r
  c.fn = nil

  if getCurrentException().isNil:
    # this would be the body after the toplevel try statement
    discard

  if c.fn.isNil and not getCurrentException().isNil:
    raise
  return c

proc b2(c: C): C =
  # we look for non-nil exceptions
  if not c.x1.isNil:
    # it's code that's inside a try
    setCurrentException c.x1 # added boilerplate
  elif not c.e.isNil:
    # finally when exception was thrown
    setCurrentException c.e # added boilerplate

  # it's in a try so we need to catch it
  try:
    inc r
    doAssert getCurrentExceptionMsg() == "something"

    if getCurrentException().isNil:

      # proceed into the toplevel try body
      doAssert false, "this should not run"

    # go to toplevel finally
    c.fn = f2

  except CpsException as x2:
    # we catch exceptions here for (at least) two reasons:
    # - we know we may have a finally to execute,
    # - we need to set the exception correctly,
    c.x2 = (ref CatchableError)(x2)
    # go to toplevel finally
    c.fn = f2

  if c.fn.isNil and not getCurrentException().isNil:
    raise
  return c

proc f1(c: C): C =
  ## finally from the "middle" try

  # we look for non-nil exceptions
  if not c.x1.isNil:
    # it's code that's inside a try
    setCurrentException c.x1 # added boilerplate
  elif not c.e.isNil:
    # finally when exception was thrown
    setCurrentException c.e # added boilerplate

  # it's in a try so we need to catch it
  try:
    # finally body starts with a noop, so ...
    c.fn = b2
    return noop c

  except CpsException as x2:
    # we catch exceptions here for (at least) two reasons:
    # - we know we may have a finally to execute,
    # - we need to set the exception correctly,
    c.x2 = (ref CatchableError)(x2)

    # go to toplevel finally
    c.fn = f2

  if c.fn.isNil and not getCurrentException().isNil:
    raise
  return c

proc b(c: C): C =
  ## inner-most try body successful; this is the code
  ## after that try statement

  # we know we're in a try, which means /we/ have to catch
  # any exceptions for those clauses, or any finally

  try:

    # user code for body after the try
    raise newException(ValueError, "something")

    # we will definitely travel to the "middle" finally now
    c.fn = f1

  except CpsException as x1:
    # we catch exceptions here for (at least) two reasons:
    # - we know we may have a finally to execute,
    # - we need to set the exception correctly,
    c.x1 = (ref CatchableError)(x1)
    # we will definitely travel to the "middle" finally now
    c.fn = f1

  if c.fn.isNil and not getCurrentException().isNil:
    raise
  return c

proc b1(c: C): C =
  # interior of clause
  if not c.e.isNil:
    setCurrentException c.e  # added boilerplate

  # we know we're in a try, which means /we/ have to catch
  # any exceptions for those clauses, or any finally

  try:
    # user code for clause
    inc r
    doAssert c.e.msg == "some error"

    # after the try
    raise newException(ValueError, "something")

    # we will definitely travel to the "middle" finally now
    c.fn = f1
  except CpsException as x1:
    # we catch exceptions here for (at least) two reasons:
    # - we know we may have a finally to execute,
    # - we need to set the exception correctly,
    c.x1 = (ref CatchableError)(x1)
    # we will definitely travel to the "middle" finally now
    c.fn = f1

  if c.fn.isNil and not getCurrentException().isNil:
    raise
  return c

proc foo(): C =
  var c = C()

  try:
    raise newException(CatchableError, "some error")
    c.fn = b
    return noop c
  except CatchableError as e:
    c.e = e
    c.fn = b1
    return noop c

doAssertRaises ValueError:
  var c = foo()
  while c != nil and c.fn != nil:
    c = c.fn(c)

doAssert r == 3, "r is " & $r