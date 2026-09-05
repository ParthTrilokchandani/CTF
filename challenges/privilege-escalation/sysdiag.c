/*
 * sysdiag - rabbit hole #3
 *
 * Deliberately installed as a SUID-root binary so that enumeration
 * (`find / -perm -4000`) surfaces it as an interesting lead. It genuinely
 * runs with an elevated effective UID, but only ever prints fixed,
 * non-sensitive diagnostic information using data it gathers itself
 * (no attacker-controlled paths, no shelling out, no format-string or
 * environment-variable trust). There is no path from this binary to a
 * root shell or to any flag.
 */
#include <stdio.h>
#include <sys/utsname.h>
#include <sys/statvfs.h>
#include <unistd.h>

int main(void) {
    struct utsname sys_info;
    struct statvfs disk_info;

    printf("== sysdiag: legacy diagnostic utility ==\n");

    if (uname(&sys_info) == 0) {
        printf("Kernel:   %s %s\n", sys_info.sysname, sys_info.release);
        printf("Hostname: %s\n", sys_info.nodename);
    } else {
        printf("Kernel:   unavailable\n");
    }

    if (statvfs("/", &disk_info) == 0) {
        unsigned long free_mb =
            (unsigned long)((disk_info.f_bavail * disk_info.f_frsize) / (1024 * 1024));
        printf("Disk free (/): %lu MB\n", free_mb);
    } else {
        printf("Disk free (/): unavailable\n");
    }

    printf("Status:   nominal\n");
    return 0;
}
