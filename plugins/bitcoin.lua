local API = 'https://api.bitcoincharts.com/v1/markets.json'
local GetRates = function()
    local Body, Code, Headers = https.request(API)
    if Code ~= 200 then
        error(string.format("Status code returned: %i", Code))
    end

    local Data = json.decode.decode(Body)
    if not Data then
        error("Could not decode JSON.")
    end

    local Rates = {}
    for _, Market in pairs(Data) do
        local Rate = {}
        Rate.high = Market.high
        Rate.low = Market.low
        Rate.avg = Market.avg
        Rate.currency = Market.currency
        Rates[Market.symbol] = Rate
    end
    return Rates
end

local FormatData = function(Rate, Key)
    local Value = Rate[Key]
    local Currency = Rate.currency

    return string.format("%.2f %s", Value, Currency)
end

local DefaultRates = {'mtgoxUSD', 'mtgoxPLN', 'bitcurexPLN'}
plugin.AddCommand('btc', 0, function(Username, Channel)
    local Rates = GetRates()
    for _, Key in pairs(DefaultRates) do
        local Rate = Rates[Key]
        local High = FormatData(Rate, 'high')
        local Low = FormatData(Rate, 'low')
        local Avg = FormatData(Rate, 'avg')
        local Data = string.format("%s: high: %s, low: %s, avg: %s", Key, High, Low, Avg)
        Channel:Say(Data)
    end
end, "Show exchange BTC rate on popular exchanges.")

