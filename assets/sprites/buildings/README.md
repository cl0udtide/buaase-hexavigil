# Building Sprite Naming

Building sprites are loaded by logical keys from `data/buildings.json`.

Supported single-building layouts:

```text
assets/sprites/buildings/<visual_key>.png
assets/sprites/buildings/<visual_key>/<visual_key>.png
assets/sprites/buildings/<visual_key>/<visual_key>_idle_000.png
assets/sprites/buildings/<visual_key>/idle/<visual_key>_idle_000.png
```

Wood wall and war shrine variants may be grouped in a family folder:

```text
assets/sprites/buildings/wood_wall/wood_wall_idle_000.png
assets/sprites/buildings/wood_wall/wood_wall_0000_isolated.png
assets/sprites/buildings/wood_wall/wood_wall_0001_n.png
assets/sprites/buildings/wood_wall/wood_wall_0010_e.png
assets/sprites/buildings/wood_wall/wood_wall_0011_ne.png
assets/sprites/buildings/wood_wall/wood_wall_0100_s.png
assets/sprites/buildings/wood_wall/wood_wall_0101_ns.png
assets/sprites/buildings/wood_wall/wood_wall_0110_es.png
assets/sprites/buildings/wood_wall/wood_wall_0111_nes.png
assets/sprites/buildings/wood_wall/wood_wall_1000_w.png
assets/sprites/buildings/wood_wall/wood_wall_1001_nw.png
assets/sprites/buildings/wood_wall/wood_wall_1010_ew.png
assets/sprites/buildings/wood_wall/wood_wall_1011_new.png
assets/sprites/buildings/wood_wall/wood_wall_1100_sw.png
assets/sprites/buildings/wood_wall/wood_wall_1101_nsw.png
assets/sprites/buildings/wood_wall/wood_wall_1110_esw.png
assets/sprites/buildings/wood_wall/wood_wall_1111_nesw.png
assets/sprites/buildings/war_shrine/war_shrine_inactive.png
assets/sprites/buildings/war_shrine/war_shrine_active.png
```

The generic destroyed sprite key is `generic_destroyed_building`.
