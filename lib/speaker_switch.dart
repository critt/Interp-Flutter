class SpeakerSwitch {
  Speaker _currentSpeaker = Speaker.subject;

  void setSpeaker(Speaker speaker) {
    _currentSpeaker = speaker;
  }
  
  Speaker get currentSpeaker => _currentSpeaker;
}

enum Speaker {
  subject,
  object
}