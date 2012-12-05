/* This is the javascript for the opt-in page. It sets/deletes
   a cookie which controls whether the flashproxy javascript
   code should run or disable itself. */

var COOKIE_NAME = "flashproxy";
/* In seconds. */
var COOKIE_LIFETIME = 60 * 60 * 24 * 365;

window.addEventListener("load", function () {

    /* This checks if cookies are enabled in the browser.
       document.cookie has special behavior, if cookies
       are disabled it will not retain any values stored in it. */
    function cookies_enabled() {
        /*Not supported in all browsers.*/
        if (navigator.cookieEnabled) {
            return true;
        } else if (navigator.cookieEnabled === undefined) {
            document.cookie = "test";
            if (document.cookie.indexOf("test") !== -1)
                return true;
        }
        return false;
    }

    /* Updates the text telling the user what his current setting is.*/
    function update_setting_text() {
        var setting = document.getElementById("setting");
        var prefix = "<p>Your current setting is: ";

        if (document.cookie.indexOf(COOKIE_NAME) !== -1) {
            setting.innerHTML = prefix + "use my browser as a proxy. " +
                                         "Click no below to change your setting.</p>";
        } else {
            setting.innerHTML = prefix + "do not use my browser as a proxy. " +
                                         "Click yes below to change your setting.</p>";
        }
    }

    function set_cookie() {
        document.cookie = COOKIE_NAME + "=; max-age=" + COOKIE_LIFETIME;
    }

    function del_cookie() {
        document.cookie = COOKIE_NAME + "=; expires=Thu, 01 Jan 1970 00:00:00 GMT";
    }

    if (cookies_enabled()) {
        var buttons = document.getElementById("buttons");
        buttons.addEventListener("click", update_setting_text);
        document.getElementById("yes").addEventListener("click", set_cookie);
        document.getElementById("no").addEventListener("click", del_cookie);
        buttons.style.display = "block";
        update_setting_text();
    } else {
        document.getElementById("cookies_disabled").style.display = "block";
        /* Manually set the text here as it refers to the buttons,
           which won't show up if cookies are disabled. */
        document.getElementById("setting").innerHTML = "<p>Your current setting is: " +
                                                       "do not use my browser as a proxy.</p>";
    }
});
