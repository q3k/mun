plugin.AddCommand('c', -1, function(Username, Channel, Line)
	local Body, Code = https.request('https://www.wolframalpha.com/input/?i=' .. Line)
	if Code == 200 then
		Body:gsub('{"stringified": "([^"]+)"', function(m)
			Channel:Say(m)
		end)
	else
		Channel:Say('Got weird status code from WA: ' .. tostring(Code))
	end
end, 'Calculate something on Wolfram Alpha')
