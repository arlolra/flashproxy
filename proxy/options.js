/* This is the javascript for the opt-in page. It sets/deletes
   a cookie which controls whether the flashproxy javascript
   code should run or disable itself. */

var COOKIE_NAME = "flashproxy";
/* max-age is not supported in IE. */
var COOKIE_LIFETIME = "Thu, 01 Jan 2020 00:00:00 GMT";

/* This wrapper will attach events correctly in older
   versions of IE. */
function add_event(elem, evt, handler) {
    if (elem.attachEvent)
        elem.attachEvent("on" + evt, handler);
    else
        elem.addEventListener(evt, handler);
}

function set_cookie_allowed() {
    document.cookie = COOKIE_NAME + "= ;path=/ ;expires=" + COOKIE_LIFETIME;
}

function set_cookie_disallowed() {
    document.cookie = COOKIE_NAME + "= ;path=/ ;expires=Thu, 01 Jan 1970 00:00:00 GMT";
}

add_event(window, "load", function () {

    function cookie_present() {
        var cookies = document.cookie.split(";");

        for (i in cookies) {
            var name = cookies[i].split("=")[0];

            while (name[0] === " ")
                name = name.substr(1);
            if (COOKIE_NAME === name)
                return true;
        }
        return false;
    }

    /* Updates the text telling the user what his current setting is.*/
    function update_setting_text() {
        var setting = document.getElementById("setting");
        var prefix = "<p>Your current setting is: ";

        if (cookie_present()) {
            setting.innerHTML = prefix + "use my browser as a proxy. " +
                                         "Click no below to change your setting.</p>";
        } else {
            setting.innerHTML = prefix + "do not use my browser as a proxy. " +
                                         "Click yes below to change your setting.</p>";
        }
    }

    if (navigator.cookieEnabled) {
        var buttons = document.getElementById("buttons");
        add_event(buttons, "click", update_setting_text);
        buttons.style.display = "block";
        update_setting_text();
    } else {
        document.getElementById("cookies_disabled").style.display = "block";
        /* Manually set the text here as otherwise it will refer to
           the buttons, which don't show if cookies are disabled. */
        document.getElementById("setting").innerHTML = "<p>Your current setting is: " +
                                                       "do not use my browser as a proxy.</p>";
    }
});