import '../domain/sentence_detail.dart';

final mockSentences = List.generate(150, (index) {
  final baseIndex = index % 4; // 4 unique sentences
  final startTime = index * 5;
  final uniqueId = '${index + 1}';

  switch (baseIndex) {
    case 0:
      return SentenceDetail(
        id: uniqueId,
        text: 'Where have you been all this time? ($index)',
        translation: '你这段时间都去哪了？',
        phonetic: '/wer hæv juː bɪn ɔːl ðɪs taɪm/',
        grammarNotes: {
          'have been':
              'Present Perfect (现在完成时) suggests an action that started in the past and continues to the present.',
          'all this time':
              'Indicates the entire duration from a past point until now.',
        },
        startTime: Duration(seconds: startTime),
        endTime: Duration(seconds: startTime + 5),
      );
    case 1:
      return SentenceDetail(
        id: uniqueId,
        text: 'I was just waiting for you outside. ($index)',
        translation: '我刚才就在外面等你。',
        phonetic: '/aɪ wəz dʒʌst ˈweɪtɪŋ fɔːr juː ˌaʊtˈsaɪd/',
        grammarNotes: {
          'was waiting':
              'Past Continuous (过去进行时) describes an action that was in progress at a specific time in the past.',
        },
        startTime: Duration(seconds: startTime),
        endTime: Duration(seconds: startTime + 5),
      );
    case 2:
      return SentenceDetail(
        id: uniqueId,
        text: 'Did you forget to bring your phone? ($index)',
        translation: '你是不是忘了带手机？',
        phonetic: '/dɪd juː fərˈɡɛt tuː brɪŋ jʊər foʊn/',
        grammarNotes: {
          'forget to':
              'followed by an infinitive implies failing to perform a task.',
        },
        startTime: Duration(seconds: startTime),
        endTime: Duration(seconds: startTime + 5),
      );
    case 3:
    default:
      return SentenceDetail(
        id: uniqueId,
        text: 'No, I just ran out of battery. ($index)',
        translation: '没，我只是没电了。',
        phonetic: '/noʊ, aɪ dʒʌst ræn aʊt ʌv ˈbætəri/',
        grammarNotes: {
          'ran out of': 'Phrasal verb meaning to use up a supply of something.',
        },
        startTime: Duration(seconds: startTime),
        endTime: Duration(seconds: startTime + 5),
      );
  }
});

// Backward compatibility
final mockSentence = mockSentences[0];
