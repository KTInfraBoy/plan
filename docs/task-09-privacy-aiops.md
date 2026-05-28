# Task 09 — Privacy AIOps / AI 로그 분석

로그를 AI에 보낼 때 개인정보(IP 등)를 Regex로 마스킹 후 전달. 장애 원인 자동 분석.

## 흐름

```
Core DB (원시 로그)
    │
    ↓
Regex Masking
  - IP 주소   → [MASKED_IP]
  - 이메일    → [MASKED_EMAIL]
  - 전화번호  → [MASKED_PHONE]
    │
    ↓
Gemini AI API
  - 로그 패턴 분석
  - 장애 원인 추론
  - 해결 방안 제시
    │
    ↓
ChatOps (Discord / Slack / Telegram) 알림
```

## 체크리스트

- [ ] 로그 수집 스크립트 작성
- [ ] Regex 마스킹 함수 구현
- [ ] Gemini AI API 연동
- [ ] 분석 결과 포맷 정의
- [ ] ChatOps 웹훅 알림 연동
- [ ] 마스킹 패턴 테스트 (실제 로그로 검증)

## Regex 마스킹 예시 (Python)

```python
import re

def mask_pii(log: str) -> str:
    # IP 주소
    log = re.sub(
        r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
        '[MASKED_IP]', log
    )
    # 이메일
    log = re.sub(
        r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
        '[MASKED_EMAIL]', log
    )
    # 전화번호
    log = re.sub(
        r'01[016789]-?\d{3,4}-?\d{4}',
        '[MASKED_PHONE]', log
    )
    return log
```

## Gemini AI 연동 예시 (Python)

```python
import google.generativeai as genai

genai.configure(api_key=os.environ["GEMINI_API_KEY"])
model = genai.GenerativeModel("gemini-1.5-flash")

def analyze_log(masked_log: str) -> str:
    prompt = f"""
    다음은 서버 로그입니다. 장애 원인을 분석하고 해결 방법을 제시하세요.
    ---
    {masked_log}
    """
    response = model.generate_content(prompt)
    return response.text
```

## Secrets

| Key | 설명 |
|-----|------|
| `GEMINI_API_KEY` | Google AI Studio에서 발급 |
| `DISCORD_WEBHOOK_URL` | 장애 알림용 웹훅 |
