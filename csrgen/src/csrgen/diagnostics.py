"""Errors and warnings shared by all generation stages."""

class TableError(ValueError):
    """Invalid register table or generator configuration."""



class ReservedFieldWarning(UserWarning):
    """Reserved field metadata is ignored in favor of constant zero / RO."""



class NumericCellWarning(UserWarning):
    """A numeric Excel cell was used as decimal where the column is hexadecimal."""



class CodeToolError(ValueError):
    """An external RTL checker or formatter could not complete."""
