if not component.screen or not component.gpu then
    error("A GPU and screen are required for this image.")
end

while 1 do
    io.read()
    coroutine.yield()
end
