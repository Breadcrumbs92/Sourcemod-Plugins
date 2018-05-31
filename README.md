# Sourcemod-Plugins
Assorted gameplay-modifying sourcemod plugins, intended and built for use in ***Synergy*** only. Running these in other source games may result in unintended behavoir/complete unoperational-ness.

# Disclaimer
None of this trash is coded or commented well. Tread lightly.

## Spite (`p_spiteartifact.sp`)

#### *Spite rains from the heavens.*

* Players, enemies, and props create a shower of grenades when they die.
* These grenades have a chance to be explosive barrels or combine balls!
* Hostile NPCs are made immune to most explosives, but friendly NPCs aren't.
  * Hostile NPCs are still vulnerable to explosive barrels.
  * Becuase you can't really prevent them from dying in the midst of explosive chaos, essential NPCs (i.e. alyx, barney, vortigaunts) *are* made immune to explosives. 
  * Any problematic entity can be made immune to everything with console command `spite_make_immune`.
* Explosive-based weapons have new behavoir to keep them relevant in combat.
  * Player-thrown frag grenades and RPGs create explosive barrels upon detonation
  * SMG grenades create volatile dumpsters upon detonation, which later supernova into incredibly fast-moving combine balls after a random amount of time

### Console variables:
* `spite_ball_supernova_chance`: The chance out of 100 for an enemy to explode into combine balls upon death.
* `spite_barrel_supernova_chance`: The chance out of 100 for an enemy to explode into explosive barrels upon death.
* `spite_do_supernovas`: Whether or not to spawn combine balls or explosive barrels at all.

## Spirit (`p_spiritartifact.sp`)

#### *The flame of spirit burns ever brighter.*

* Being shot pushes you away from the attacker.
* Shooting weapons pushes you backward.
* The amount you are pushed increases exponentionally the lower your health is.
* Fall damage is entirely negated.
* Falling far enough causes combine balls to explode from where you landed.

## Command (`p_commandartifact.sp`)

#### *Unlimited power is under our command.*

* Quickly double-tapping the USE key while holding a weapon throws a bugbait.
* When the bugbait lands, it drains all of the ammo for that weapon and activates a special effect where the bugbait landed.
  * The pistol causes an implosion, sucking all objects inward for a short amount of time. The effect is more extreme the more ammo is consumed.
  * The magnum causes all objects in a radius to become immune to damage for three seconds. The radius is larger the amore ammo is consumed.
  * The SMG creates a friendly rebel that, after a random amount of time, is violently converted into 5 to 7 explosive barrels. Spawning a rebel consumes exactly 45 ammo.
  * The AR2 instantly detonates all combine balls and explosive barrels in a large radius, replacing them with suit batteries and healthkits respectively. The radius is larger the more ammo is consumed.
  * The shotgun temporarily sets the health of all entities in a radius to 1. While the effect is active, health cannot be replenished. The radius is larger the more ammo is consumed.

## Kin (`p_kinartifact.sp`)

#### *Their kin will rise from the ashes.*

* When NPCs are killed, they transform into a lesser version of themselves.

Killed NPC | Transformation
------------ | --------------
Elite Combine Soldier | Regular Soldier
Regular Soldier | Metrocop
Metrocop | Manhack 

Killed NPC | Transformation
------------ | --------------
Zombine | Poison Zombie
Poison Zombie | Fast Zombie
Fast Zombie | Zombie
Zombie | Headcrab

Killed NPC | Transformation
------------ | --------------
Poison Headcrab | Fast Headcrab
Fast Headcrab | Headcrab

Killed NPC | Transformation
------------ | --------------
Rebel Medic | Rebel
Rebel | Citizen
Citizen | Supply Crate

Killed NPC | Transformation
------------ | --------------
Gunship | Like 50 manhacks

* Player or NPC-fired combine balls are portals that continually spawn new NPCs as they travel. Combine-fired balls create new combine soliders while player-fired balls create new rebels.
* All NPCs have a very small chance to transform into a rollermine.

### Console variables:
* `kin_rollermine_chance`: Chance out of 100 to spawn a rollermine on every entity death.
* `kin_combine_ball_interval`: How much time should pass, in seconds, before another combine soldier is created from a combine ball fired by a soldier.
* `kin_rebel_ball_interval`: How much time should pass, in seconds, before another rebel is created from a combine ball fired by a player.
* `kin_do_ball_spawning`: Whether or not fired combine balls should spawn rebels or soldiers.

## Honor (`p_honorartifact.sp`)

#### *We follow the code of honor.*

* Headshotting an enemy causes an explosion and instantly kills them.
* Bodyshotting an enemy causes all entities in a radius to turn into combine soldiers and the player loses 50 health.
* Missing an enemy causes the player to explode and instantly die.

## Trash (`p_trashartifact.sp`)

#### *Tonight, on Hoarders:*

* When the map starts, 500 random props are spawned in random locations, instantly turning it into a landfill.

## Rubber (`p_rubberartifact.sp`)

#### *The world is growing restless.*

* Props randomly bounce and fly across the map.
* The frequency of prop bouncing increases as time goes on, up to a certain cap.

## Console variables:
* `rubber_check_every_nth`: The amount of frames that need to pass before another check to bounce a prop occurs.
* `rubber_push_probability`: Chance (as a percentage) for a random prop to bounce every time a check occurs.
* `rubber_growth_factor`: The factor by which the push probability increases linearly with time.
* `rubber_growth_power`: The power to which the push probability is raised.

## Experiments (`p_newguns.sp`, `p_proto_magfield.sp`, `p_saw.sp`)

These are miscellanous and incomplete plugins that are being used to test future ones. They are subject to removal.


