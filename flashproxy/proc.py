import errno
import os
import socket
import stat
import pwd

DEFAULT_CLIENT_TRANSPORT = "websocket"

# Return true iff the given fd is readable, writable, and executable only by its
# owner.
def check_perms(fd):
    mode = os.fstat(fd)[0]
    return (mode & (stat.S_IRWXG | stat.S_IRWXO)) == 0

# Drop privileges by switching ID to that of the given user.
# http://stackoverflow.com/questions/2699907/dropping-root-permissions-in-python/2699996#2699996
# https://www.securecoding.cert.org/confluence/display/seccode/POS36-C.+Observe+correct+revocation+order+while+relinquishing+privileges
# https://www.securecoding.cert.org/confluence/display/seccode/POS37-C.+Ensure+that+privilege+relinquishment+is+successful
def drop_privs(username):
    uid = pwd.getpwnam(username).pw_uid
    gid = pwd.getpwnam(username).pw_gid
    os.setgroups([])
    os.setgid(gid)
    os.setuid(uid)
    try:
        os.setuid(0)
    except OSError:
        pass
    else:
        raise AssertionError("setuid(0) succeeded after attempting to drop privileges")

# A decorator to ignore "broken pipe" errors.
def catch_epipe(fn):
    def ret(self, *args):
        try:
            return fn(self, *args)
        except socket.error, e:
            try:
                err_num = e.errno
            except AttributeError:
                # Before Python 2.6, exception can be a pair.
                err_num, errstr = e
            except:
                raise
            if err_num != errno.EPIPE:
                raise
    return ret
