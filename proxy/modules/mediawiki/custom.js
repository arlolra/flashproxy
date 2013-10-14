/* Flash proxy badge for MediaWiki. By Sathyanarayanan Gunasekaran.
   Requires $wgAllowUserJs to be true in the MediaWiki configuration.
   https://www.mediawiki.org/wiki/Manual:Interface/JavaScript
   This affects only your own user. Works on Wikipedia.

   Go to Preferences → Appearance → Custom JavaScript.
   You will end up editing common.js; paste in this code and save it. */

$('#p-personal ul').append('<li><iframe src="//crypto.stanford.edu/flashproxy/embed.html" width="80" height="15" frameborder="0" scrolling="no"></iframe></li>');
