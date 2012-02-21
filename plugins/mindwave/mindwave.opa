package mindwave

/**
 * Plugin for MindWave (NeuroSky - http://www.neurosky.com/)
 */
module MindWave {

  client function is_present() {
    (%%mindwave.is_present%%)()
  }

  client function get_thinking_level() {
    (%%mindwave.get_thinking_level%%)()
  }

  client function get_relaxation_level() {
    (%%mindwave.get_relaxation_level%%)()
  }

}
