
# chapters for mpv

It's a script that lets you add, remove and edit chapters of the currently
played media, be it video or audio, local file or a stream. Chapters you create
can be saved into a separate text file and automatically loaded when you open
the same media file again.

## Features

* add a new chapter, optionally with a title
* edit existing chapter's title
* remove current chapter
* save chapters as a text file, either in the same directory as the media file
  or in a global directory
* optionally can hash file paths in an attempt to uniquely identify media files
  if chapter files are stored in a central directory
* option to automatically save/load chapter files
* option to use ffmpeg to put the chapters into the media file container as a
  metadata, so that other media players, like vlc, can make use of them
* should work on Unix and Windows (tested on Archlinux and Windows 10)

## Installation

* place **chapters.lua** in your **~/.config/mpv/scripts** directory
* optionally create a config file named **chapters.conf** in **~/.config/mpv/scripts-opts**, check out example config file
* add keybindings to your **~/.config/mpv/input.conf**, example:

  ```ini
  n       script-binding chapters/add_chapter
  ctrl+m  script-binding chapters/remove_chapter
  ctrl+.  script-binding chapters/edit_chapter
  N       script-binding chapters/write_chapters
  ctrl+,  script-binding chapters/bake_chapters
  ```

* if you want to have the ability to name/rename chapters, you'll need to install
  <https://github.com/CogentRedTester/mpv-user-input>

  * optionally create a config file for it **~/.config/mpv/user_input.conf** where
  you can configure text size and such

## Thanks

* <https://github.com/CogentRedTester/mpv-user-input> - very useful script to get
  user input, hopefully one day mpv's scripting API will have that ootb.
* <https://github.com/shinchiro/mpv-createchapter> - inspiration for writing this
  script. At first I just wanted to add to it the ability to load the saved
  chapters file, but then I wrote entirely new script with a lot more features.
  Also check out <https://github.com/dyphire/mpv-scripts> - as I was finishing
  my script and thinking how to name it, I found out that someone already wrote
  something similar. Duh... at least I got to lear some Lua in the process.
* mpv, ffmpeg and other awesome open source projects

## License

Copyright (c) 2023 Mariusz Libera <mariusz.libera@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
