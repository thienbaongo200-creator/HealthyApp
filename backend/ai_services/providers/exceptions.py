class ProviderError(Exception):
    """Safe, provider-independent failure. Never include secrets or PHI in its text."""
