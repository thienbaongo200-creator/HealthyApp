from django.conf import settings

from .exceptions import ProviderError


class GeminiProvider:
    name = "gemini"

    def __init__(self):
        api_key = getattr(settings, "GEMINI_API_KEY", "")
        if not api_key:
            raise ProviderError("Gemini is not configured.")
        try:
            from google import genai
            from google.genai import types
            timeout_ms = int(getattr(settings, "GEMINI_TIMEOUT_MS", 10_000))
            self.model_version = getattr(settings, "GEMINI_MODEL", "gemini-2.5-flash")
            self._client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=timeout_ms))
        except Exception as exc:
            raise ProviderError("Gemini client initialization failed.") from exc

    def generate_reply(self, *, message: str, context: str) -> str:
        prompt = (
            "Bạn là trợ lý sức khỏe, không chẩn đoán hoặc thay thế nhân viên y tế. "
            "Chỉ diễn giải dữ liệu được cung cấp, nêu rõ giới hạn và khuyên tìm trợ giúp khi cần.\n"
            f"Ngữ cảnh sức khỏe:\n{context}\n\nCâu hỏi:\n{message}"
        )
        try:
            response = self._client.models.generate_content(model=self.model_version, contents=prompt)
            text = getattr(response, "text", None)
            if not text:
                raise ProviderError("Gemini returned an empty response.")
            return text.strip()
        except ProviderError:
            raise
        except Exception as exc:
            # Do not propagate provider response bodies, keys, or health context.
            raise ProviderError("Gemini request failed.") from exc
