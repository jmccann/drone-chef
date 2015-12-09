2.2.1
=====
* Fix bug where cookbooks would not upload to chef server

2.2.0
=====
* Based on ChefDK 0.10.0 now (previsouly 0.9.0)

2.1.0
=====
* Can upload chef_org data to a chef server

2.0.1
=====
* bug: Download cookbooks to prepare for upload to chef server

2.0.0
=====
* Major rewrite - no breaking changes but may have introduced bugs

1.0.1
=====
* fix `berks install` not honoring ssl_verfiy when set to false

1.0.0
=====
* Use berkshelf to upload cookbooks to chef server
* Allow uploading dependency cookbooks to chef server
* Change attribute `ssl_verify_mode` to `ssl_verify`

0.3.0
=====
* Add check for if cookbook is already uploaded to supermarket

0.2.0
=====
* Allow uploading Chef cookbooks to a supermarket
 * Tested with a private supermarket, not against public

0.1.0
=====
* Allow uploading a Chef cookbook to a Chef Server
