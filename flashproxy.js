/* Are circumstances such that we should self-disable and not be a
   proxy? We take a best-effort guess as to whether this device runs on
   a battery or the data transfer might be expensive.

   Matching mobile User-Agents is complex; but we only need to match
   those devices that can also run a recent version of Adobe Flash,
   which is a subset of this list:
   https://secure.wikimedia.org/wikipedia/en/wiki/Adobe_Flash_Player#Mobile_operating_systems

   Other resources:
   http://www.zytrax.com/tech/web/mobile_ids.html
   http://googlewebmastercentral.blogspot.com/2011/03/mo-better-to-also-detect-mobile-user.html
   http://search.cpan.org/~cmanley/Mobile-UserAgent-1.05/lib/Mobile/UserAgent.pm
*/
function flashproxy_should_disable()
{
    var ua;

    ua = window.navigator.userAgent;
    if (ua != null) {
        var UA_LIST = [
            /\bmobile\b/i,
            /\bandroid\b/i,
            /\bopera mobi\b/i,
        ];

        for (var i = 0; i < UA_LIST.length; i++) {
            var re = UA_LIST[i];

            if (ua.match(re)) {
                return true;
            }
        }
    }

    return false;
}

/* Create and return a DOM fragment:
<span id=BADGE_ID>
<a href=FLASHPROXY_INFO_URL>
    child
</a>
</span>
*/
function flashproxy_make_container(child)
{
    var BADGE_ID = "flashproxy-badge";
    var FLASHPROXY_INFO_URL = "https://crypto.stanford.edu/flashproxy/";

    var container;
    var a;

    container = document.createElement("span");
    container.setAttribute("id", "flashproxy-badge");
    a = document.createElement("a");
    a.setAttribute("href", FLASHPROXY_INFO_URL);
    a.appendChild(child)
    container.appendChild(a);

    return container;
}

/* Create and return a DOM fragment:
<object width=WIDTH height=HEIGHT>
    <param name="movie" value=SWFCAT_URL>
    <param name="flashvars" value=FLASHVARS>
    <embed src=SWFCAT_URL width=WIDTH height=HEIGHT flashvars=FLASHVARS></embed>
</object>
*/
function flashproxy_make_badge()
{
    var WIDTH = 70;
    var HEIGHT = 23;
    var FLASHVARS = "";
    var SWFCAT_URL = "https://crypto.stanford.edu/flashproxy/swfcat.swf";

    var object;
    var param;
    var embed;

    object = document.createElement("object");
    object.setAttribute("width", WIDTH);
    object.setAttribute("height", HEIGHT);

    param = document.createElement("param");
    param.setAttribute("name", "movie");
    param.setAttribute("value", SWFCAT_URL);
    object.appendChild(param);
    param = document.createElement("param");
    param.setAttribute("name", "flashvars");
    param.setAttribute("value", FLASHVARS);
    object.appendChild(param);

    embed = document.createElement("embed");
    embed.setAttribute("src", SWFCAT_URL);
    embed.setAttribute("width", WIDTH);
    embed.setAttribute("height", HEIGHT);
    embed.setAttribute("flashvars", FLASHVARS);
    object.appendChild(embed);

    return object;
}

/* Create and return a non-functional placeholder badge DOM fragment:
<img src=BADGE_IMAGE_URL border="0">
*/
function flashproxy_make_dummy_badge()
{
    var BADGE_IMAGE_URL = "https://crypto.stanford.edu/flashproxy/badge.png";

    var img;

    img = document.createElement("img");
    img.setAttribute("src", BADGE_IMAGE_URL);
    img.setAttribute("border", 0);

    return img;
}

function flashproxy_badge_insert()
{
    var badge;
    var e;

    if (flashproxy_should_disable()) {
        badge = flashproxy_make_dummy_badge();
    } else {
        badge = flashproxy_make_badge();
    }

    /* http://intertwingly.net/blog/2006/11/10/Thats-Not-Write for this trick to
       insert right after the <script> element in the DOM. */
    e = document;
    while (e.lastChild && e.lastChild.nodeType == 1) {
        e = e.lastChild;
    }
    e.parentNode.appendChild(flashproxy_make_container(badge));
}

flashproxy_badge_insert();
