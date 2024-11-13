class SpeakerSwitch {
  Speaker _currentSpeaker = Speaker.object;

  void setSpeaker(Speaker speaker) {
    _currentSpeaker = speaker;
  }
  
  void toggleSpeaker() {
    _currentSpeaker = _currentSpeaker == Speaker.subject ? Speaker.object : Speaker.subject;
  }
  
  Speaker get currentSpeaker => _currentSpeaker;
}

enum Speaker {
  subject,
  object
}