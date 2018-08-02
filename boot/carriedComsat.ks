DELETEPATH(SCRIPTPATH()).
RUNPATH("0:/copy/Basic").
COPYPATH("0:/comSat","1:/comSat").
COPYPATH("0:/satDeploy","1:/satDeploy").
SET CORE:BOOTFILENAME TO "satDeploy".
SHUTDOWN.