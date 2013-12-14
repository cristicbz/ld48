settings = {
  world = {
    small_step_size = 1 / 120.0,
    screen_width = 10,
    screen_pixel_width = 1280,
    screen_pixel_height = 720,
    gravity = -0.02,
    global_drag = 0.165 * 10
  },

  debug = {
    show_lines = false,
    disable_lightmap = false,
  },

  priorities = {
    foreground = 100,
    lightmap = 101,
  },

  entities = {
    swimmer = {
      texture_path = "assets/swimmer64.png",
      size = 64 / 1280 * 10 / 3,
      mass = 0.41,
      restitution = 0.2,
      friction = 0.05,
      move_force = 0.5,
    }
  },

  effects = {
    lightmap = {
      light_texture_path = "assets/spotlight-map.png",
      small_light_size = 0.4
    }
  },

  levels = {
    {
      definition_path = "assets/l1.level",
      background = "assets/level1.png",
    }
  }
}

