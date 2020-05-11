PARAMETER file.
SWITCH TO 1.
LIST FILES IN fl.
FOR f IN fl {
    DELETEPATH(f).
}
COPYPATH("0:/boot/" + file, "1:/boot/" + file).
SET CORE:BOOTFILENAME TO "/boot/" + file.
REBOOT.