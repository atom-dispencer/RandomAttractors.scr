# RandomAttractors.scr

If you don't care about how the thing works and just want to use it, skip to 
    [#Usage](#Usage).
Instructions for building and testing the project are under [#Building](#Building) and
    [#Options](#Options).

## Usage

### Windows Installation

1) Grab `RandomAttractors.scr` from the Releases page (or build it yourself).
2) Place `RandomAttractors.scr` in your `System32` (e.g. `C:/Windows/System32/`).
3) Select `RandomAttractors` in the Control Panel (Just search `screensaver` 
   or `change screen saver` or something like that in your search bar or 
   start menu).

### Linux Installation

This can be a little harder because there isn't a standard way to deal with
    screensavers in Linux... The way that I dealt with it for this project,
    based on my [FireworksGL.scr](https://github.com/atom-dispencer/FireworksGL.scr),
    is documented as a [GitHub Gist](https://gist.github.com/atom-dispencer/06cafa2787eed2d0a6f8a12e991ee6c9)


The screensaver automatically closes when you click any button, but *not*
   if you just move the mouse because I personally find that annoying.

## Options

**/s** - Run the screensaver full screen.

**/p** - Run the screensaver in preview/debug mode (windowed)

*Not yet supported (but you don't need them anyway):*

**/?** - Show a help dialogue with these options.

**/c** - Show a configuration dialogue. No options currently supported.

## Building

The project uses CMake, and has been successfully compiled and run on 
*Windows 11* (via WSL & Visual Studio) and on *Pop!_OS* (with `make`).

To build, you will need a copies of `libglfw3` and `glfw3.h` to link against.
GLFW is a git submodule of this project (in `lib/glfw`), so you can build it on
Linux or WSL by:

```sh
cd RandomAttractors.scr
git submodule update --init --recursive
# Generate the build files with CMake
cmake -S lib/glfw -B lib/glfw/build     # Or use the CMake GUI
# Build GLFW
cd lib/glfw/build
make
```

Once you've built GLFW, you can build the project in the same way:

```sh
cd RandomAttractors.scr
cmake -S . -B build     # Or use the CMake GUI
cd build
make
```



