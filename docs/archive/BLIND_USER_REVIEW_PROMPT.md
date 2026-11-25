# 시각장애인 관점 앱 평가 프롬프트

코드만 읽는 에이전트(Claude 서브에이전트, Codex 등)에게 그대로 붙여 넣는다.
에이전트끼리는 영어로 대화하므로 본문은 영어다. 결과는 한국어로 받도록 마지막 줄에 적어 두었다.
실기기(TalkBack) 확인을 대신하지 않는다. 코드로 본 예상 평가다.

---

You are evaluating a Flutter Android app, **Touch Bridge**, from the point of view of its real users. The repository is the current working directory. Read the code; do not modify any file.

## What the app does

Blind and low-vision people cannot use flat touch panels on appliances such as microwaves. A small gantry with a SwitchBot Bot is mounted over the panel. The phone app takes a voice command such as "30초 돌려줘" or "햇반 데워줘", turns it into a button sequence (local rules first, then an AI backend), asks the user to confirm, and sends it over BLE. The device moves to each button and presses it. A guardian (family member or caregiver) does the one-time setup: registers the appliance and sets the button positions.

Start with `CLAUDE.md` (safety contracts and UX rules), then `lib/screens/`, `lib/widgets/`, and `lib/services/tts_service.dart`.

## Personas — evaluate each one separately

1. **Minsu, 62, totally blind for 10 years.** Uses TalkBack daily, swiping left and right to move between items and double-tapping to activate. Not technical. Lives alone and uses the microwave several times a day.
2. **Jiyoung, 35, low vision (about 0.05 acuity).** Does not use TalkBack. Uses large text and high contrast and holds the phone close to her face. Taps directly on the screen.
3. **Minsu's daughter, 30, sighted guardian.** Sets up the device once, and comes back when a button position drifts or the appliance changes.

## Tasks to walk through (trace the actual code path for each)

For Minsu and Jiyoung:
- A. Open the app for the very first time with no appliance registered. What do they hear and see? Do they know what to do next?
- B. With one microwave registered, heat food for 30 seconds by voice, from app launch to "done". Include the confirmation step. Minsu answers "네" by voice. Jiyoung taps the button.
- C. Use an ambiguous or risky command (for example "10번 3번 눌러줘", or a sentence containing a negation such as "돌리지 마"). Is anything sent to the device?
- D. Stop the device mid-sequence. Can they find the stop control quickly without seeing it? Is the result announced honestly (stopped and confirmed, versus only sent)?
- E. The phone loses the BLE connection mid-sequence. What do they hear? Can they recover alone?
- F. After the timer ends, do they know whether the appliance actually ran? Check the power (CT) status text.

For the guardian:
- G. Register a new microwave and set the button positions, starting from the home screen with no devices.
- H. Fix one drifted button position on an already registered appliance.
- I. Rename the appliance and then delete it.

## What to check on every step

- **Screen reader:** focus order, labels (no "button" word duplicated in labels), headers, live regions, and anything that TalkBack cannot reach (gesture-only actions, long-press-only actions, swipe-only PageViews).
- **Speech:** is every result, failure and stop announced, even while TalkBack is on (TTS priority `result` or `emergency`)? Are there double announcements (TTS plus TalkBack reading the same text)? Is the wording plain Korean that a non-technical person understands, with no jargon such as ESP, BLE, mapping or calibration on user screens?
- **Error safety:** can a single accidental tap or a misheard word make the device press something? Is confirmation required where it should be, and absent where it would only slow the user down (navigation, stop)?
- **Honesty:** does the app ever claim "done" or "pressed" without an acknowledgement from the device?
- **Timeouts:** anything that expires faster than 20 seconds while the user is expected to act (WCAG 2.2.1)?
- **Low vision:** text size under large text, contrast, touch target size (at least 48 dp), and anything clipped at 200% font scale.
- **Separation:** do guardian-only functions (registering, button positions, hardware) ever appear on user screens?

## Output

1. A table per persona: task, result (works / works with friction / blocked), and one-line reason.
2. The top 10 problems ranked by harm to the user. For each one give `file:line`, what the user experiences (in their words, for example "I hear nothing after saying 네"), why it happens in the code, and a concrete fix.
3. What already works well and must not be broken by future changes (at most 5 points).
4. A score from 1 to 10 per persona for "could use it alone without help", with one sentence of justification.

Only report problems you can point to in the code. Mark anything you could not confirm from code alone as "needs device check". Do not pad the list.

**Write the final report in Korean.**
