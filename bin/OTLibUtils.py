# -*-mode: python; fill-column: 75; tab-width: 8; coding: utf-8; encoding: utf-8-dos -*-

#? should this be in SimpleFormat?

class MqlError(RuntimeError):
    pass


def gRetvalToPython(sString, lElts):
    # raises MqlError
    sType = lElts[4]
    sVal = lElts[5]
    if sVal == "":
        return ""
    if sType == 'string':
        gRetval = sVal
    elif sType == 'error':
        #? should I raise an error?
        raise MqlError(sVal)
    elif sType == 'datetime':
        #? how do I convert this
        # I think it's epoch seconds as an int
        # but what TZ? TZ of the server?
        # I'll treat it as a float like time.time()
        # but probably better to convert it to datetime
        gRetval = float(sVal)
    elif sType == 'int':
        gRetval = int(sVal)
    elif sType == 'json':
        gRetval = json.loads(sVal)
    elif sType == 'double':
        gRetval = float(sVal)
    elif sType == 'none':
        gRetval = None
    elif sType == 'void':
        gRetval = None
    else:
        print "WARN: unknown type i=%s in %r" % (sType, lElts,)
        return None
    return gRetval

