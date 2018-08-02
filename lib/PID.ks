FUNCTION pid {PARAMETER l, i. LOCAL dT IS time:seconds-l[5]. if dT>0{LOCAL D IS 0. SET l[3] TO (l[3]+i*l[1]*dT). SET l[3] TO max(l[6],min(l[7],l[3])). IF l[10] = TRUE {SET D TO (l[11]-l[4])/dT. SET l[4] TO l[11].}ELSE{SET D TO (i-l[4])/dT. SET l[4] TO i.}SET l[5] TO time:seconds. RETURN max(l[8],min(l[9],i*l[0]+l[3]+D*l[2])).}}
FUNCTION pid_new {PARAMETER P,I,D. RETURN LIST(P,I,D,0,0,time:seconds,-1,1,-1,1,FALSE,0).}
FUNCTION pid_gains {PARAMETER l,P,I,D. SET l[0] TO P. SET l[1] TO I. SET l[2] TO D.}
FUNCTION pid_limits {PARAMETER l,nI,xI,nO,xO. SET l[6] TO nI. SET l[7] TO xI. SET l[8] TO nO. SET l[9] TO xO.}
FUNCTION pid_dOverride {PARAMETER l,d. SET l[10] TO TRUE. SET l[11] TO d.}