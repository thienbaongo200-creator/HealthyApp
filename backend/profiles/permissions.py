"""Compatibility imports; authorization is implemented in core.permissions."""

from core.permissions import IsProfileOwnerOrShared, PermissionService

__all__ = ["IsProfileOwnerOrShared", "PermissionService"]
