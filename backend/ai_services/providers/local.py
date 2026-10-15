from .base import AssistantProvider


class LocalRuleProvider:
    name = "local"
    model_version = "rules-v1"

    def generate_reply(self, *, message: str, context: str) -> str:
        msg = message.casefold()
        terms = {
            "huyết áp": ("huyết áp", "áp lực máu", "blood pressure"),
            "HEART_RATE": ("nhịp tim", "tim đập", "mạch", "heart rate"),
            "BLOOD_GLUCOSE": ("đường huyết", "glucose", "đường máu"),
            "WEIGHT": ("cân nặng", "giảm cân", "tăng cân", "weight"),
            "SLEEP": ("giấc ngủ", "ngủ", "mất ngủ", "sleep"),
        }
        focus = next((key for key, words in terms.items() if any(word in msg for word in words)), None)
        matches = [line for line in context.splitlines() if focus and (line.startswith(focus) or (focus == "huyết áp" and line.startswith("Huyết áp:")))]
        answer = "\n".join(matches) if matches else (f"Chưa có bản ghi {focus.lower()} trong 30 ngày gần đây." if focus else f"Tóm tắt các chỉ số trong 30 ngày gần đây:\n{context}")
        return (f"{answer}\n\nGợi ý: tiếp tục đo đúng hướng dẫn và ghi lại thời điểm/hoàn cảnh đo. "
                "Kết quả chỉ mang tính tham khảo, không thay thế chẩn đoán y tế. "
                "Nếu có triệu chứng nghiêm trọng hoặc bất thường kéo dài, hãy liên hệ cơ sở y tế.")
