import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/voice/voice_listening_screen.dart';

/// 마이크가 앱·낭독기 안내를 다시 받으면 명령으로 보내지 않는다(실기: 낭독기의
/// '말씀해 주세요'가 녹음돼 서버로 갔다).
void main() {
  const prompts = ['말씀해 주세요', '듣고 있습니다', '30초 조리를 시작합니다. 실행할까요?'];

  test('안내 문구 그대로면 메아리로 본다', () {
    expect(VoiceListeningScreenState.echoMatches('말씀해 주세요', prompts), isTrue);
    expect(VoiceListeningScreenState.echoMatches('말씀해주세요.', prompts), isTrue);
    expect(VoiceListeningScreenState.echoMatches('실행할까요', prompts), isTrue);
  });

  test('사용자 명령은 메아리가 아니다', () {
    expect(VoiceListeningScreenState.echoMatches('30초 돌려줘', prompts), isFalse);
    expect(VoiceListeningScreenState.echoMatches('네', prompts), isFalse);
    expect(VoiceListeningScreenState.echoMatches('아니요', prompts), isFalse);
  });

  test('되읽은 사용자 말(따옴표 안)은 메아리 판단에서 뺀다', () {
    const reask = ['"30초 돌려줘"라고 들었어요. 맞으면 "네", 아니면 "아니요"라고 말씀해 주세요.'];
    expect(VoiceListeningScreenState.echoMatches('30초 돌려줘', reask), isFalse);
    expect(VoiceListeningScreenState.echoMatches('라고 들었어요 맞으면', reask), isTrue);
  });

  test('사용자 말 앞뒤에 섞인 앱 문구는 지운다', () {
    expect(VoiceListeningScreenState.stripEchoPhrases('듣고 있습니다 30초 돌려줘'), '30초 돌려줘');
    expect(VoiceListeningScreenState.stripEchoPhrases('듣고있습니다'), '');
    expect(VoiceListeningScreenState.stripEchoPhrases('30초 돌려줘'), '30초 돌려줘');
    expect(VoiceListeningScreenState.stripEchoPhrases('취소'), '취소');
  });
}
