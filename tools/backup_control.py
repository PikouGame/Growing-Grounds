"""Cooperative cancellation shared by every file/hash/archive operation."""
from contextlib import contextmanager
from contextvars import ContextVar


class Cancelled(RuntimeError):
    pass


_check = ContextVar('gg_backup_check', default=lambda: None)


def checkpoint():
    _check.get()()


@contextmanager
def cancellable(check):
    token = _check.set(check)
    try:
        checkpoint()
        yield
    finally:
        _check.reset(token)
