
# chapters for mpv

It's a script that lets you add, remove and edit chapters of the currently
played media, be it video or audio, local file or a stream. Chapters you create
can be saved into a separate text file and automatically loaded when you open
the same media file again.

This version of the script requires mpv 0.38 or newer.

## Features

* add a new chapter, optionally with a title
* edit existing chapter's title
* remove current chapter
* save chapters as a text file, either in the same directory as the media file
  or in a global directory
* save chapters as an xml or txt file
* optionally can hash file paths in an attempt to uniquely identify media files
  if chapter files are stored in a central directory
* option to automatically save/load chapter files
* option to use ffmpeg to put the chapters into the media file container as a
  metadata, so that other media players, like vlc, can make use of them
* embed chapters in place in mkv container using mkvpropedit
* should work on Unix and Windows (tested on Archlinux and Windows 10)

## Installation

* place **chapters.lua** in your **~/.config/mpv/scripts** directory
* optionally create a config file named **chapters.conf** in **~/.config/mpv/script-opts**, check out example config file
* add keybindings to your **~/.config/mpv/input.conf**, example:

  ```ini
  n       script-binding chapters/add_chapter
  ctrl+m  script-binding chapters/remove_chapter
  ctrl+.  script-binding chapters/edit_chapter
  N       script-binding chapters/write_chapters
  ctrl+b  script-binding chapters/write_xml
  B       script-binding chapters/write_txt
  ctrl+,  script-binding chapters/bake_chapters
  K       script-binding chapters/mkvpropedit
  ```

## Thanks

* <https://github.com/shinchiro/mpv-createchapter> - inspiration for writing this
  script. At first I just wanted to add to it the ability to load the saved
  chapters file, but then I wrote entirely new script with a lot more features.
  Also check out <https://github.com/dyphire/mpv-scripts> - as I was finishing
  my script and thinking how to name it, I found out that someone already wrote
  something similar. Duh... at least I got to lear some Lua in the process.
* mpv, ffmpeg and other awesome open source projects
