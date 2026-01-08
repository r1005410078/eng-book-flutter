import '../domain/sentence_detail.dart';

final mockSentence = SentenceDetail(
  id: '1',
  text: 'Where have you been all this time?',
  translation: '你这段时间都去哪了？',
  phonetic: '/wer hæv juː bɪn ɔːl ðɪs taɪm/',
  grammarNotes: {
    'have been':
        'Present Perfect (现在完成时) suggests an action that started in the past and continues to the present.',
    'all this time':
        'Indicates the entire duration from a past point until now.',
  },
  startTime: const Duration(seconds: 0),
  endTime: const Duration(seconds: 5),
);
