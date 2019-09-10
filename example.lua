require('HttpServer')

local app = express.new()

-- Register a new middleware that prints the url of every request
app:use(function(req,res,next) 
    print("Current url: "..req.url)
    next()
end)

-- Register a new route that just returns an html site that says "HELLO WORLD!"
app:get('/helloworld',function(req,res)
    res:send('<html><head></head><body>HELLO WORLD!</body></html>')
end)

-- Serve the file `home.html` when visiting `/home`
app:get('/home',express.static('home.html'))

-- Serve all files that are in the folder `http` at url `/libs/...`
-- (To be more accurate I'm talking about all files starting with `http/`.)
app:use('/libs',express.static('http'))

-- 404 Handler
app:get('*', function(req,res)
    res:send('<html><head></head><body>Not found</body></html>')
end)

app:listen(80)