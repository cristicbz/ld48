settings = { world = {
    small_step_size = 1 / 120.0,
    screen_width = 100,
    screen_pixel_width = 1280,
    screen_pixel_height = 720,
    gravity = -0.02,
    global_drag = 0.165
  },

  debug = {
    show_lines = false,
    disable_lightmap = false,
  },

  priorities = {
    background = 10,
    doodads = 20,
    foreground = 30,
    lightmap = 40,
  },

  collision_masks = {
    obstacle = 0x0001,
    player = 0x0002,
    collectible = 0x0004,
    lethal = 0x0008,
    nonlethal = 0x0010,
  },

  entities = {
    swimmer = {
      texture_path = "assets/swimmer64.png",
      size = 1.67,
      mass = 1.0,
      restitution = 0.1,
      friction = 0.05,
      move_force = 5.0,
      recoil_strength = 0.3,

      flashlight_pos = { 1.17, 0.5 },
      flashlight_scale = { 0.4, 0.26 },
      flashlight_color = { 1.0, 1.0, 1.0, 0.8 },

      launcher_strength = 10.0,
    },

    light_ball = {
      texture_path = "assets/throwable.png",
      sprite_size = 2.0,
      collision_ratio = 0.3125,
      mass = 4.0,
      restitution = 0.8,
      friction = 0.0,
      light_scale = 1.0,
      light_color = { 0.5, 1.0, 1.0, 1.0 },
      min_collect_time = 1.0,
    },

    coral_killer = {
      texture_path = "assets/spikycoral.png",
      collision_height = 32 / 64,
      collision_width  = 58 / 64,
    },

    rock_killer = {
      texture_path = "assets/rockshards.png",
      collision_height = 32 / 64,
      collision_width  = 58 / 64,
    },

    algae_glower = {
      texture_path = "assets/glowalgae.png",
      activate_radius = 6.0,
      light_scale = 1.8,
      light_color = { 0.1, 1.0, 0.6, 0.15 },
    },
  },

  effects = {
    lightmap = {
      light_texture_path = "assets/spotlight-map.png",
      small_light_size = 10,
    }
  },

  levels = {
    {
      definition_path = "assets/l1.level",
      background = "assets/level1.png",
    }
  }
}

