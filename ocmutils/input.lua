local input = {}

input.confirm = function(prompt, yesAnswer)
    if prompt == nil then
        prompt = "Are you sure you want to continue? "
    end
    if yesAnswer == nil then
        yesAnswer = {"yes", "y"}
    end

    io.write(prompt)
    answer = io.read()

    if answer == nil then
        print()
        return false
    end
    if answer == false then
        return false
    end

    for _, yes in ipairs(yesAnswer) do
        if answer:lower() == yes then
            return true
        end
    end
    return false
end

input.getFromList = function(list, listStrings, name, first)
    if #list == 0 then
        return false
    end

    if #list == 1 then
        return list[1]
    end

    print("Available " .. name .. ":")
    print()

    for i, el in ipairs(listStrings) do
        print(i .. ") " .. el)
    end
    print()

    local number = nil
    while true do
        io.write("Select a number from 1 to " .. #list .. ": ")
        number = io.read()
        if number == nil or number == false then
            return nil
        end
        number = tonumber(number)
        if number ~= nil and number >= 1 and number <= #list then
            break
        end
        print("Invalid number.")
    end

    if list[number] == nil then
        return nil
    end

    print()
    return list[number]
end

return input
