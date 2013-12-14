settings = {
  world = {
    small_step_size = 1 / 120.0,
    screen_width = 10,
    screen_pixel_width = 960,
    screen_pixel_height = 540,
    gravity = -0.02,
    global_drag = 0.165 * 20
  },

  debug = {
    show_lines = false,
  },

  priorities = {
    foreground = 100,
    lightmap = 101,
  },

  entities = {
    swimmer = {
      texture_path = "assets/phone.png",
      size = 0.15,
      mass = 0.41,
      restitution = 0.2,
      friction = 0.05,
      move_force = 1.0,
    }
  },

  effects = {
    lightmap = {
      light_texture_path = "assets/Spotlight-Map.png",
      small_light_size = 1.0
    }
  },
}

