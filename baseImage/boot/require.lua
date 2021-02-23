local isPlainFile(path)
    return component.filesystem.exists(path) and not component.filesystem.isDirectory(path)
end

function require(path)
    if not path then
        return nil
    end

    if isPlainFile(path) then
        return exec(path)
    end

    if isPlainFile("/" + path) then
        return exec(path)
    end

    if isPlainFile("/lib" + path) then
        return exec(path)
    end
    if isPlainFile("/lib/" + path) then
        return exec(path)
    end

    return nil
end