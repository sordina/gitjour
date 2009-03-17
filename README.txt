= gitjour

* http://github.com/technomancy/gitjour

== DESCRIPTION:

Automates zeroconf-powered serving and cloning of git repositories.

== SYNOPSIS:

  % gitjour serve [project_dir] [name_to_advertise_as]
  Registered phil-gitjour on port 9418. Starting service.

  % gitjour list
  Gathering for up to 5 seconds...
  === phil-gitjour on pdp10.local.:9418 ===
    gitjour (clone|pull) phil-gitjour

  % gitjour clone phil-gitjour
  Gathering for up to 5 seconds...
  Connecting to pdp10.local.:9418
  Initialized empty Git repository in /home/phil/phil-gitjour/.git/
  [...]
  Resolving deltas: 100% (342/342), done.

  % gitjour pull phil-gitjour
  Gathering for up to 5 seconds...
  Connecting to pdp10.local.:9418
  From git://pdp10.local.:9418
   * branch            master     -> FETCH_HEAD
  Updating 5ede61a..781bc4d
  [...]
  4 files changed, 35 insertions(+), 80 deletions(-)

== REQUIREMENTS:

* git
* dnssd, which requires development headers to bonjour or avahi
  See dnssd documentation for details.

== INSTALL:

* sudo gem install gitjour

== LICENSE:

(The MIT License)

Copyright (c) 2008 Chad Fowler, Evan Phoenix, and Rich Kilmer

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
