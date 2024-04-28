from pymxs import runtime as rt
import codecs

def getRootNode():
    rootScene = rt.rootScene
    worldSubAnim = rootScene[rt.Name('world')]
    return worldSubAnim.object

def hasAnimatedProps(obj):
    try:
        if obj.GetNumKeys() > 0:
            return True
    except:
        pass

    try:
        for a in obj.SubAnims:
            if hasAnimatedProps(a):
                return True
    except:
        pass
    try:
        for a in obj.Children:
            if hasAnimatedProps(a):
                return True
    except:
        pass

    return False

def deleteAllKeyframesRec(obj):
    try:
        if obj.GetNumKeys() > 0:
            obj.DeleteKeys(2) #TRACK_DOALL
    except:
        pass

    try:
        for a in obj.SubAnims:
            deleteAllKeyframesRec(a)
    except:
        pass
    try:
        for a in obj.Children:
            deleteAllKeyframesRec(a)
    except:
        pass

    return False


def pyIsSceneAnimated():
    root = getRootNode()
    for c in root.Children:
        if hasAnimatedProps(c):
            return True
    return False

def pyDeleteAllKeyframes():
    deleteAllKeyframesRec(getRootNode())
    for l in range(rt.LayerManager.count):
        deleteAllKeyframesRec(rt.LayerManager.GetLayer(l))

def pyAddStringToFileIfNotPresent(search_string, file_path):
    with codecs.open(file_path, "a+", encoding='UTF-8') as search_file:
        search_file.seek(0)
        for line in search_file:
            if line.strip().replace("\\", "/") == search_string :
                return True
        search_file.write(search_string + "\n")
    return False

def pyGetFileModifiedTimestamp(file_path) :
    import os
    #with milliseconds
    return str(format(round(os.path.getmtime(file_path), 3), '.3f')).replace(".", "")
