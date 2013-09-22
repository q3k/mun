local LoadTime = plugin.CurrentTime()

plugin.AddCommand('test', 0, function(User, Channel)
    Channel:Say(string.format("I've been loaded at %i.", LoadTime))
end, "Test command!")
