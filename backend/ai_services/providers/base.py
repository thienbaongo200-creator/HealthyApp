from typing import Protocol


class AssistantProvider(Protocol):
    name: str
    model_version: str

    def generate_reply(self, *, message: str, context: str) -> str:
        """Generate a response or raise ProviderError on provider failure."""
