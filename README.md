###bind proxy maintenance scripts

These are maintenance scripts for use with *bind* acting as an ad blocking proxy.
Their purpose is to refresh and format domain lists into master zone definitions for
inclusion in a bind config file.

The scripts load [maintained lists](http://adblockplus.org/en/subscriptions) of ad hosts intended for use by the
adblock plus firefox extension.

* bind_refresh.pl is written for use under launchd (osx 10.5+).

* bind_refresh_old.pl is written for osx 10.4 and is adaptable to unixes.

Run periodically within a maintenance process.
***
This library is free software. You can redistribute it and/or modify it under the same terms as Perl itself.
