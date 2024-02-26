## Blackhole Playground

For the 2024 Swift Student Challenge I created a raytracer which incorporates general relativity
to be able to render blackholes (in realtime). The playground also includes a 2d version of the
raytracer which produces in interactive diagram showing the paths of light rays emitted from a
light source in the presence of a black hole.

The aim is to help students who are learning about General Relativity to visualize problems and
gain an intuition for what's going on behind the maths. It also just looks pretty cool.

The raytracing is done by numerically integrating a second order differential equation derived
from Schwarzschild's solution to the Einstein Field Equations for the specific case of a single
non-rotating spherical mass in an otherwise empty universe. In reality blackholes almost always
have significant angular momentum, and I'd be interested in investigating how much a blackhole's
rotation affects how it looks.

The playground features an onboarding flow that runs everytime the you reopen the app, since it
is a playground. But if turned into an actual app I'd of course clean up the onboarding flow and
make it only run once.

Please note that much of the app was crammed pretty close to the deadline so there's definitely
more that I could clean up.

## Notable inaccuracies

- Doesn't consider the velocity of the observer (which may or may not affect the produced images)
- Doesn't simulate phenoma that affect the frequency of light, such as the relativistic doppler shift
  effect.
- The accretion disk is only vaguely physically based (the gradient colouring is based on 
  blackbody radiation). To make it more realistic without introducing a janky looking static
  texture, a fluid simulation of some sort would likely be required (which I may try my hand
  at some day...)
- And probably more!

## Starmap credits

> NASA/Goddard Space Flight Center Scientific Visualization Studio. Gaia DR2: ESA/Gaia/DPAC.
> Constellation figures based on those developed for the IAU by Alan MacRobert of Sky and
> Telescope magazine (Roger Sinnott and Rick Fienberg).
