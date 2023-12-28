enum IconAsset {
  // Icons outlined
  infoCircle('info_circle'),
  warningCircle('warning_circle'),
  warning('warning'),
  notesBoardPencil('notes_board_pencil'),
  check('check'),
  x('x'),
  download('download'),
  chevronLeft('chevron_left'),
  paperClip('paper_clip'),
  video('video'),
  videoCrossed('video_crossed'),
  group('group'),
  camera('camera'),
  archive('archive'),
  house('house'),
  pinMark('pin_mark'),
  speechBubbleLines('speech_bubble_lines'),
  wallet('wallet'),
  calendar('calendar'),
  calendarX('calendar_x'),
  clock('clock'),
  arrowRight('arrow_right'),
  user('user'),
  login('login'),
  logout('logout'),
  bellNotification('bell_notification'),
  email('email'),
  smartphoneSms('smartphone_sms'),
  bin('bin'),
  hourglass('hourglass'),

  //Flags
  flagUnitedKingdom('flag_uk'),
  flagSweden('flag_se'),
  flagNorway('flag_no'),
  flagDenmark('flag_dk'),
  flagFinland('flag_fi'),
  flagGermany('flag_de'),
  flagNetherlands('flag_nl'),

  // Icons filled
  paperplaneFilled('paperplane_filled'),
  houseFilled('house_filled'),

  // Icons other
  filePdf('file_pdf'),
  fileOtherFormats('file_other_formats'),
  fileError('file_error'),

  // Illustrations
  illustrationCases('illustration_cases');

  final String iconPath;

  const IconAsset(String iconName) : iconPath = 'assets/icn_$iconName.svg';
}
