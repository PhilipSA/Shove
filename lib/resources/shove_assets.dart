enum TextureAssets {
  shover('assets/textures/knuffare.svg'),
  leaper('assets/textures/hoppare.svg'),
  blocker('assets/textures/ankare.svg'),
  thrower('assets/textures/kastare.svg'),
  invShover('assets/textures/inv_knuffare.svg'),
  invLeaper('assets/textures/inv_hoppare.svg'),
  invBlocker('assets/textures/inv_ankare.svg'),
  invThrower('assets/textures/inv_kastare.svg');

  final String assetPath;

  const TextureAssets(this.assetPath);
}

enum AudioAssets {
  bonk('assets/sounds/bonk.mp3'),
  chains('assets/sounds/chains.mp3'),
  move('assets/sounds/move.mp3'),
  scream('assets/sounds/scream.mp3'),
  throwSound('assets/sounds/throw.mp3');

  final String assetPath;

  const AudioAssets(this.assetPath);
}
